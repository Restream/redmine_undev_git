module RedmineUndevGit::Services
  class MessageParser

    attr_reader :ref_keywords, :fix_keywords

    # ref_keywords should be nil or blank if any reference keyword is allowed
    def initialize(ref_keywords, fix_keywords)
      @ref_keywords, @fix_keywords = ref_keywords, fix_keywords
    end

    def parse_message_for_references(message)
      issue_ids = []
      scan_message_with_pattern(message, regexp_pattern_for_references) do |issue_id, _, _|
        issue_ids << issue_id
      end
      issue_ids.uniq
    end

    def parse_message_for_logtime(message)
      log_entries = []
      scan_message_with_pattern(message, regexp_pattern_without_keywords) do |issue_id, _, hours|
        log_entries << [issue_id, hours] unless hours.blank?
      end
      log_entries
    end

    def parse_message_for_hooks(message)
      hooks = []
      scan_message_with_pattern(message, regexp_pattern_for_hooks) do |issue_id, action, _|
        hooks << [issue_id, action] unless action.strip.blank?
      end
      hooks
    end

    def regexp_pattern_for_references
      @regexp_pattern_for_references ||=
        ref_keywords.blank? ? regexp_pattern_without_keywords : regexp_pattern_with_keywords(ref_keywords)
    end

    def regexp_pattern_for_hooks
      @regexp_pattern_for_hooks ||= regexp_pattern_with_keywords(fix_keywords)
    end

    def regexp_pattern_without_keywords
      /(?<action>\s?)(?<refs>#\d+(\s+@#{Changeset::TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{Changeset::TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i
    end

    def regexp_pattern_with_keywords(keywords)
      kw_regexp = keywords.collect { |kw| Regexp.escape(kw) }.join('|')
      /([\s\(\[,-]|^)((?<action>#{kw_regexp})[\s:]+)(?<refs>#\d+(\s+@#{Changeset::TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{Changeset::TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i
    end

    def scan_message_with_pattern(message, pattern, &block)
      message.scan(pattern) do |match|
        action, refs = match[0], match[1]

        refs.scan(/#(?<issue_id>\d+)(\s+@(?<hours>#{Changeset::TIMELOG_RE}))?/i).each do |match|
          block.call(match[0].to_i, action, match[1])
        end
      end
    end

  end
end
