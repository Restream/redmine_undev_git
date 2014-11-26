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
        link_revisions_to_issues(new_revisions)
        log_time_from_revisions(new_revisions)

        hooks_revisions = find_hooks_revisions
        apply_hooks_to_issues_by_revisions(hooks_revisions)

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
        committer = user_by_email(revision.cemail)
        next unless committer

        parser.parse_message_for_logtime(revision.message).each do |issue_id, hours|
          if issue = Issue.find_by_id(issue_id)
            log_time(:issue => issue, :user => committer, :hours => hours, :spent_on => revision.cdate)
            link_revision_to_issue(revision, issue_id)
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

    def apply_hooks_to_issues_by_revisions(revisions)
      revisions.each do |revision|
        parser.parse_message_for_hooks(revision.message) do |issue_id, action|
          apply_hook(revision, action, issue_id)
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

    def parser
      @parser ||= MessageParser.new(any_ref_keyword? ? nil : ref_keywords, fix_keywords)
    end
  end
end
