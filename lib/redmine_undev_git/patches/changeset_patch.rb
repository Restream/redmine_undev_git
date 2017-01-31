require_dependency 'changeset'

module RedmineUndevGit
  module Patches
    module ChangesetPatch

      def self.prepended(base)
        base.class_eval do

          serialize :branches, Array

          belongs_to :rebased_from,
            class_name: 'Changeset'

          has_one :rebased_to,
            class_name:  'Changeset',
            foreign_key: 'rebased_from_id'

          skip_callback :create, :after, :scan_for_issues,
            if: lambda { self.repository.is_a? Repository::UndevGit }

        end
      end

      # parse commit message for ref and fix keywords with issue_ids
      def parse_comment_for_issues(ref_keywords, fix_keywords)
        ret = { ref_issues: [], fix_issues: {}, log_time: {} }

        return ret if comments.blank?

        # keywords used to reference issues
        ref_keywords     = ref_keywords.downcase.split(',').collect(&:strip)
        ref_keywords_any = ref_keywords.delete('*')
        # keywords used to fix issues
        fix_keywords     = fix_keywords.downcase.split(',').collect(&:strip)

        kw_regexp = (ref_keywords + fix_keywords).uniq.collect { |kw| Regexp.escape(kw) }.join('|')

        comments.scan(/([\s\(\[,-]|^)((#{kw_regexp})[\s:]+)?(#\d+(\s+@#{Changeset::TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{Changeset::TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i) do |match|
          action, refs = match[2].to_s.downcase, match[3]
          next unless action.present? || ref_keywords_any

          refs.scan(/#(\d+)(\s+@#{Changeset::TIMELOG_RE})?/).each do |m|
            issue, hours = find_referenced_issue_by_id(m[0].to_i), m[2]
            if issue
              ret[:ref_issues] << issue
              if fix_keywords.include?(action)
                ret[:fix_issues][issue] ||= []
                ret[:fix_issues][issue] << action
              end
              if hours
                ret[:log_time][issue] ||= []
                ret[:log_time][issue] << hours
              end
            end
          end
        end

        ret[:ref_issues].uniq!
        ret
      end

      def make_references_to_issues(issues)
        issues.each do |issue|

          # remove references to old commits that was rebased
          if rebased_from
            issue.changesets.delete(rebased_from)
          end

          issue.changesets << self
        end
      end

      def full_text_tag(ref_project = nil)
        tag = scmid? ? scmid.to_s : "r#{revision}"

        if repository && repository.identifier.present?
          tag = "#{repository.identifier}|#{tag}"
        end

        tag = "commit:#{tag}" if scmid?

        tag = "#{project.identifier}:#{tag}" if ref_project && ref_project != project

        tag
      end

      def log_time_wrapped(issue, hours)
        log_time(issue, hours)
      end
    end
  end
end
