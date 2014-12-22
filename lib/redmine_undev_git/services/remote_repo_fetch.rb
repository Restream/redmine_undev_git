module RedmineUndevGit::Services
  # fetch remote repository
  class RemoteRepoFetch
    attr_reader :repo

    HookRequest = Struct.new(:issue, :hook, :repo_revision, :keyword, :branch) do
      def valid?
        issue && hook && repo_revision && keyword.present? && (hook.any_branch? == branch.blank?)
      end

      def validate!
        raise "HookRequest #{self} invalid." unless valid?
      end
    end

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
      clear_cache
      initialize_repository
      download_changes
      return if head_revisions == repo.tail_revisions
      repo.transaction do
        update_repo_refs
        update_revisions_refs

        new_revisions = find_new_revisions
        link_revisions_to_issues(new_revisions)
        log_time_from_revisions(new_revisions)

        apply_hooks_to_issues

        save_new_tail
      end
    end

    def refetch
      repo.transaction do
        clear_tail
        repo.clear_all
        scm.remove_repo
        fetch
      end
    end

    def save_new_tail
      repo.tail_revisions = head_revisions
      repo.save!
    end

    def clear_tail
      repo.tail_revisions = []
      repo.save!
    end

    def update_repo_refs
      stored_refs = repo.refs.pluck(:name)
      new_refs = head_branches - stored_refs
      new_refs.each { |new_ref| repo.refs.create!(name: new_ref) }
    end

    def update_revisions_refs
      repo.revisions.each do |repo_revision|
        update_remote_repo_revision_refs(repo_revision)
      end
    end

    def find_new_revisions
      head_revs = head_revisions
      tail_revs = repo.tail_revisions

      return [] if head_revs == tail_revs

      # get new commits. ignore commits without issue_id in message
      scm.revisions(head_revs, tail_revs, grep: '#')
    end

    def link_revisions_to_issues(revisions)
      revisions.each do |revision|
        parser.parse_message_for_references(revision.message).each do |issue_id|
          link_revision_to_issue(revision, issue_id)
        end
      end
    end

    def log_time_from_revisions(revisions)
      return unless Setting.commit_logtime_enabled?

      revisions.each do |revision|
        parser.parse_message_for_logtime(revision.message).each do |issue_id, hours|
          committer = user_by_email(revision.cemail)
          issue = Issue.find_by_id(issue_id)
          if committer && issue
            log_time(issue: issue, user: committer, hours: hours, revision: revision)
          end
        end
      end
    end

    def log_time(options)
      revision = options[:revision]
      repo_revision = repo_revision_by_git_revision(revision)
      time_entry = TimeEntry.new(
          user: options[:user],
          hours: options[:hours],
          issue: options[:issue],
          spent_on: revision.cdate,
          comments: notes_for_issue_timelog(repo_revision)
      )
      time_entry.remote_repo_revision = repo_revision
      time_entry.activity = log_time_activity unless log_time_activity.nil?

      if time_entry.save
        repo_revision.ensure_issue_is_related(options[:issue])
      else
        log "TimeEntry could not be created by remote revision (#{options.inspect}): #{time_entry.errors.full_messages}"
      end
    end

    def log_time_activity
      if Setting.commit_logtime_activity_id.to_i > 0
        TimeEntryActivity.find_by_id(Setting.commit_logtime_activity_id.to_i)
      end
    end

    def apply_hooks_to_issues
      revisions = find_hooks_revisions

      revisions.each do |revision|
        parser.parse_message_for_hooks(revision.message).each do |issue_id, action|

          repo_revision = repo_revision_by_git_revision(revision)

          apply_hooks_to_issue_by_repo_revision(issue_id, action, repo_revision)
        end
      end
    end

    def apply_hooks_to_issue_by_repo_revision(issue_id, action, repo_revision)

      issue = Issue.find_by_id(issue_id)

      unless Policies::ApplyHooks.allowed?(repo_revision.committer, issue)
        log "Forbidden. User (redmine: #{repo_revision.committer.try(:login)}; git: #{repo_revision.committer_string}) try to change #{issue_id} by remote commit: #{repo_revision.uri}"
        return
      end

      apply_hook_proc = ->(hook, branch) {
        req               = HookRequest.new
        req.issue         = issue
        req.hook          = hook
        req.repo_revision = repo_revision
        req.keyword       = action
        req.branch        = branch
        req.validate!

        apply_hook(req)
      }

      any_branch_applied = false

      project_hooks = all_applicable_hooks.find_all do |h|
        h.is_a?(ProjectHook) ? h.project_id == issue.project_id : true
      end

      repo_revision.branches.each do |branch|
        hook = project_hooks.detect { |h| h.applicable_for?(action, branch) }
        next unless hook

        if hook.any_branch?
          apply_hook_proc.call(hook, nil) unless any_branch_applied
          any_branch_applied = true
        else
          apply_hook_proc.call(hook, branch)
        end
      end
    end

    def repo_ref_by_name(branch)
      @refs_cache ||= {}
      @refs_cache[branch] ||= repo.refs.where(name: branch).first_or_create
    end

    def find_hooks_revisions
      scm.revisions(nil, nil, grep: fix_keywords)
    end

    def repo_revision_by_git_revision(revision)
      @revisions_cache ||= {}
      @revisions_cache[revision.sha] ||=
          repo.revisions.find_by_sha(revision.sha) ||
              create_remote_repo_revision(revision)
    end

    def create_remote_repo_revision(revision)
      repo_revision = repo.revisions.create!(
          author:          user_by_email(revision.aemail),
          committer:       user_by_email(revision.cemail),
          sha:             revision.sha,
          author_name:     revision.aname,
          author_email:    revision.aemail,
          committer_name:  revision.cname,
          committer_email: revision.cemail,
          message:         revision.message,
          author_date:     revision.adate,
          committer_date:  revision.cdate
      )
      update_remote_repo_revision_refs(repo_revision)
      repo_revision
    end

    def user_by_email(email)
      @users_by_email_cache ||= {}
      unless @users_by_email_cache.has_key?(email)
        @users_by_email_cache[email] = repo.site.find_user_by_email(email)
      end
      @users_by_email_cache[email]
    end

    def update_remote_repo_revision_refs(repo_revision)
      old_branches = repo_revision.branches
      new_branches = scm.branches(repo_revision.sha).map(&:name)
      (new_branches - old_branches).each do |branch|
        repo_revision.refs << repo_ref_by_name(branch)
      end
    end

    def link_revision_to_issue(revision, issue_id)
      return unless issue_id

      user = user_by_email(revision.cemail) || User.anonymous

      issue = Issue.find_by_id(issue_id, include: :project)
      if issue && Policies::ReferenceToIssue.allowed?(user, issue)
        repo_revision = repo_revision_by_git_revision(revision)
        repo_revision.ensure_issue_is_related(issue)
      end
    end

    def apply_hook(req)
      # link always
      req.repo_revision.ensure_issue_is_related(req.issue)

      # change issue only if hook was not applied
      return if hook_was_applied?(req)

      req.hook.apply_for_issue(
          req.issue,
          user:  req.repo_revision.committer,
          notes: notes_for_issue_change(req.repo_revision)
      )
      journal_id = req.issue.last_journal_id

      save_fact_of_applying_hook(req, journal_id)
    end

    def save_fact_of_applying_hook(req, journal_id)
      req.repo_revision.applied_hooks.create!(
          hook:         req.hook,
          ref:          req.branch && repo_ref_by_name(req.branch),
          issue:        req.issue,
          journal_id:   journal_id,
          author_email: req.repo_revision.author_email,
          author_date:  req.repo_revision.author_date,
          keyword:      req.keyword,
          branch:       req.branch
      )
    end

    def hook_was_applied?(req)
      repo.applied_hooks.where(
          issue_id: req.issue.id,
          author_email: req.repo_revision.author_email,
          author_date: req.repo_revision.author_date,
          keyword: req.keyword,
          branch: req.branch
      ).any?
    end

    def notes_for_issue_change(repo_revision)
      ll(Setting.default_language, :text_changed_by_remote_revision_hook, repo_revision.redmine_uri)
    end

    def notes_for_issue_timelog(repo_revision)
      ll(Setting.default_language, :text_time_logged_by_changeset, repo_revision.redmine_uri)
    end

    def download_changes
      scm.fetch!
    end

    def local_path
      @local_path_cache ||= File.join(self.repo_storage_dir, 'REMOTE_REPOS', repo.id.to_s)
    end

    def initialize_repository
      if scm.repository_exists?
        fetch_url = scm.fetch_url
        scm.fetch_url = repo.url if fetch_url != repo.url
      else
        scm.clone_repository
      end
    end

    def scm
      @scm_cache ||= begin
        repo.update_attribute(:root_url, local_path) if repo.root_url.blank?
        RedmineUndevGit::Services::GitAdapter.new(repo.url, repo.root_url)
      end
    end

    def head_revisions
      scm.branches.map(&:sha).sort.uniq
    end

    def head_branches
      scm.branches.map(&:name).uniq
    end

    # keywords used to fix issues
    def fix_keywords
      @fix_keywords_cache ||= all_applicable_hooks.map do |hook|
        hook.keywords.map { |keyword| keyword.downcase.strip }
      end.flatten.uniq
    end

    # is there asterisk in reference keywords?
    def any_ref_keyword?
      if @any_ref_keyword_cache.nil?
        @any_ref_keyword_cache = Setting.commit_ref_keywords.split(',').collect(&:strip).include?('*')
      end
      @any_ref_keyword_cache
    end

    # keywords used to reference issues
    def ref_keywords
      unless @ref_keywords_cache
        @ref_keywords_cache = Setting.commit_ref_keywords.downcase.split(',').collect(&:strip)
        @ref_keywords_cache.delete('*')
      end
      @ref_keywords_cache
    end

    # return all applicable hooks in that order:
    # 1. hooks for project (without hooks for specific repository)
    # 1.1. for specific branch
    # 1.2. for any branch
    # 2. global hooks
    # 2.1. for specific branch
    # 2.2. for any branch
    def all_applicable_hooks
      @all_applicable_hooks_cache ||=
          ProjectHook.global.by_position.partition { |h| !h.any_branch? }.flatten +
          GlobalHook.by_position.partition { |h| !h.any_branch? }.flatten
    end

    def parser
      @parser_cache ||= MessageParser.new(any_ref_keyword? ? nil : ref_keywords, fix_keywords)
    end

    def log(message)
      Rails.logger.warn(message) if Rails.logger
    end

    def clear_cache
      instance_variables.each do |var|
        instance_variable_set(var, nil) if var.to_s =~ /_cache$/
      end
    end
  end
end
