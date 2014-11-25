module RedmineUndevGit::Services
  # fetch remote repository
  class RemoteRepoFetch
    attr_reader :repo

    include Redmine::I18n

    cattr_accessor :repo_storage_dir
    self.repo_storage_dir = Redmine::Configuration['scm_repo_storage_dir'] || begin
      rpath = Rails.root.join('repos')
      rpath.symlink? ? File.readlink(rpath) : rpath
    end

    def initialize(remote_repo)
      raise(ServiceError, 'Fatal: remote_repo is not persisted.') unless remote_repo.persisted?
      @repo = remote_repo
    end

    def fetch
      initialize_repository
      download_changes
      repo.transaction do

        new_revisions = find_new_revisions
        parse_revisions_for_references(new_revisions)
        parse_revisions_for_timelog(new_revisions)

        hooks_revisions = find_hooks_revisions
        parse_revisions_for_hooks(hooks_revisions)

        # save new tail
        repo.tail_revisions = head_revisions
        repo.save!
      end
    end

    def find_new_revisions
      head_revs = head_revisions
      tail_revs = repo.tail_revisions

      return [] if head_revs == tail_revs

      # get new commits. ignore commits without issue_id in message
      scm.revisions(head_revs, tail_revs, :grep => '#')
    end

    def find_hooks_revisions
      scm.revisions(nil, nil, :grep => fix_keywords)
    end

    def parse_revisions_for_references(revisions)
      pattern = regexp_pattern_for_references
      revisions.each do |revision|
        scan_message_with_pattern(revision.message, pattern) do |issue_id, _, _|
          link_revision_to_issues(revision, [issue_id])
        end
      end
    end

    def parse_revisions_for_timelog(revisions)
      return unless Setting.commit_logtime_enabled?

      pattern = regexp_pattern_without_keywords

      revisions.each do |revision|
        committer = user_by_email(revision.cemail)
        next unless committer

        scan_message_with_pattern(revision.message, pattern) do |issue_id, _, hours|
          if issue = Issue.find_by_id(issue_id)
            log_time(:issue => issue, :user => committer, :hours => hours, :spent_on => revision.cdate)
            link_revision_to_issues(revision, [issue_id])
          end
        end
      end
    end

    def log_time(options)
      time_entry = TimeEntry.new(
          :user => options[:user],
          :hours => options[:hours],
          :issue => options[:issue],
          :spent_on => options[:spent_on],
          :comments => l(:text_time_logged_by_changeset, :value => text_tag(options[:issue].project),
                         :locale => Setting.default_language)
      )
      time_entry.activity = log_time_activity unless log_time_activity.nil?

      unless time_entry.save
        Rails.logger.warn("TimeEntry could not be created by remote revision (#{options.inspect}): #{time_entry.errors.full_messages}") if Rails.logger
      end
    end

    def log_time_activity
      if Setting.commit_logtime_activity_id.to_i > 0
        TimeEntryActivity.find_by_id(Setting.commit_logtime_activity_id.to_i)
      end
    end

    def parse_revisions_for_hooks(revisions)
      pattern = regexp_pattern_with_keywords(fix_keywords)
      revisions.each do |revision|
        scan_message_with_pattern(revision.message, pattern) do |issue_id, action, _|
          apply_hook(revision, action, issue_id)
        end
      end
    end

    def regexp_pattern_for_references
      any_ref_keyword? ? regexp_pattern_without_keywords : regexp_pattern_with_keywords(ref_keywords)
    end

    def regexp_pattern_without_keywords
      /(?<action>\s?)(?<refs>#\d+(\s+@#{Changeset::TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{Changeset::TIMELOG_RE}/
    end

    def regexp_pattern_with_keywords(keywords)
      kw_regexp = keywords.collect{ |kw| Regexp.escape(kw) }.join('|')
      /([\s\(\[,-]|^)((?<action>#{kw_regexp})[\s:]+)(?<refs>#\d+(\s+@#{Changeset::TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{Changeset::TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i
    end

    def scan_message_with_pattern(message, pattern, &block)
      message.scan(pattern) do |match|
        action, refs = match[:action], match[:refs]

        refs.scan(/#(?<issue_id>\d+)(\s+(?<hours>@#{TIMELOG_RE}))?/).each do |match|
          block.call(action, match[:issue_id].to_i, match[:hours])
        end
      end
    end

    def repo_revision_by_git_revision(revision)
      @revisions_cache ||= {}
      @revisions_cache[revision.sha] ||=
          repo.revisions.find_by_sha(revision.sha) ||
              create_remote_repo_revision(revision)
      @revisions_cache[revision.sha]
    end

    def create_remote_repo_revision(revision)
      repo_revision = repo.revisions.create!(
          :author           => user_by_email(revision.aemail),
          :committer        => user_by_email(revision.cemail),
          :sha              => revision.sha,
          :author_string    => revision.author,
          :committer_string => revision.committer,
          :message          => revision.message,
          :author_date      => revision.adate,
          :committer_date   => revision.cdate
      )
      add_refs_to_remote_repo_revision(repo_revision)
      repo_revision
    end

    def user_by_email(email)
      @users_by_email ||= {}
      unless @users_by_email.has_key?(email)
        @users_by_email[email] = repo.site.find_user_by_email(email)
      end
      @users_by_email[email]
    end

    def add_refs_to_remote_repo_revision(repo_revision)
      scm.branches(repo_revision.sha).each do |branch|
        repo_ref = repo.refs.where(:name => branch.name).first_or_create
        repo_revision.refs << repo_ref
      end
    end

    def link_revision_to_issue(revision, issue_id)
      return unless issue_id

      user = user_by_email(revision.cemail) || User.anonymous

      issue = Issue.find_by_id(issue_id, :include => :project)
      if issue && Policies::ReferenceToIssue.allowed?(user, issue)
        repo_revision = repo_revision_by_git_revision(revision)
        repo_revision.related_issues << issue
      end
    end

    def apply_hook(revision, action, issue_id)
      issue = Issue.find_by_id(issue_id)
      return unless issue

      user = user_by_email(revision.cemail) || User.anonymous
      return unless Policies::ApplyHooks.allowed?(user, issue)

      revision_branches = scm.branches(revision.sha).map(&:name)

      if hook = all_applicable_hooks.detect { |h| h.applied_for?(action, revision_branches) }

        repo_revision = repo_revision_by_git_revision(revision)

        hook.apply_for_issue(
            issue,
            :user => user,
            :notes => notes_for_issue_change(repo_revision)
        )

        journal_id = issue.last_journal_id

        repo_revision.applied_hooks.create!(:hook => hook, :issue => issue, :journal_id => journal_id)

      end
    end

    def notes_for_issue_change(repo_revision)
      ll(Setting.default_language, :text_changed_by_remote_revision_hook, repo_revision.redmine_uri)
    end

    def download_changes
      scm.fetch!
    end

    def local_path
      @local_path ||= File.join(self.repo_storage_dir, 'REMOTE_REPOS', repo.id.to_s)
    end

    def initialize_repository
      scm.clone_repository unless scm.repository_exists?
    end

    def scm
      @scm ||= begin
        repo.update_attribute(:root_url, local_path) if repo.root_url.blank?
        RedmineUndevGit::Services::GitAdapter.new(repo.url, repo.root_url)
      end
    end

    def head_revisions
      scm.branches.map(&:sha).sort.uniq
    end

    # parse commit message for ref and fix keywords with issue_ids
    def parse_comments(comments)
      ret = { :ref_issues => [], :fix_issues => {}, :log_time => {} }

      return ret if comments.blank?

      kw_regexp = (ref_keywords + fix_keywords).uniq.collect{ |kw| Regexp.escape(kw) }.join('|')

      comments.scan(/([\s\(\[,-]|^)((#{kw_regexp})[\s:]+)?(#\d+(\s+@#{Changeset::TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{Changeset::TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i) do |match|
        action, refs = match[2].to_s.downcase, match[3]
        next unless action.present? || any_ref_keyword?

        refs.scan(/#(\d+)(\s+@#{Changeset::TIMELOG_RE})?/).each do |m|
          issue, hours = m[0].to_i, m[2]
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

    # keywords used to fix issues
    def fix_keywords
      @fix_keywords ||= all_applicable_hooks.map do |hook|
        hook.keywords.map { |keyword| keyword.downcase.strip }
      end.flatten.uniq
    end

    # is there asterisk in reference keywords?
    def any_ref_keyword?
      if @any_ref_keyword.nil?
        @any_ref_keyword = Setting.commit_ref_keywords.split(',').collect(&:strip).include?('*')
      end
      @any_ref_keyword
    end

    # keywords used to reference issues
    def ref_keywords
      unless @ref_keywords
        @ref_keywords = Setting.commit_ref_keywords.downcase.split(',').collect(&:strip)
        @ref_keywords.delete('*')
      end
      @ref_keywords
    end

    # return all applicable hooks in that order:
    # 1. hooks for project (without hooks for specific repository)
    # 1.1. for specific branch
    # 1.2. for any branch
    # 2. global hooks
    # 2.1. for specific branch
    # 2.2. for any branch
    def all_applicable_hooks
      @all_applicable_hooks ||=
          ProjectHook.global.by_position.partition { |h| !h.any_branch? }.flatten +
          GlobalHook.by_position.partition { |h| !h.any_branch? }.flatten
    end

  end
end
