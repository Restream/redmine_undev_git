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

      head_revs = head_revisions
      tail_revs = repo.tail_revisions

      # no changes. going home
      return if head_revs == tail_revs

      revisions = scm.revisions(head_revs, tail_revs)

      repo.transaction do

        revisions.each do |revision|
          parsed = parse_comments(revision.message)

          if parsed[:ref_issues].any? || parsed[:fix_issues].present?

            link_revision_to_issues(repo_revision, parsed[:ref_issues])
            parsed[:fix_issues].each do |issue, actions|
              apply_hooks(revision, actions, issue)
            end
          end

        end

        # get new commits (head - tail)
        # for each commits:
        #   parse commit message
        #   reference to issue
        #   apply hooks
        #   store commit ?

        # save new tail
        repo.tail_revisions = head_revisions
      end
    end

    def repo_revision_by_git_revision(revision)
      @revisions_cache ||= {}
      @revisions_cache[revision.sha] ||=
          repo.revisions.find_by_sha(revision.sha) ||
          repo.revisions.create!(
              :author           => repo.site.find_user_by_email(revision.aemail),
              :committer        => repo.site.find_user_by_email(revision.cemail),
              :sha              => revision.sha,
              :author_string    => revision.author,
              :committer_string => revision.committer,
              :message          => revision.message,
              :author_date      => revision.adate,
              :committer_date   => revision.cdate
          )
      @revisions_cache[revision.sha]
    end

    def link_revision_to_issues(revision, ref_issues_ids)
      user = repo.site.find_user_by_email(revision.cemail) || User.anonymous
      ref_issues_ids.each do |issue_id|
        issue = Issue.find_by_id(issue_id, :include => :project)
        if issue && Policies::ReferenceToIssue.allowed?(user, issue)
          repo_revision = repo_revision_by_git_revision(revision)
          repo_revision.related_issues << issue
        end
      end
    end

    def apply_hooks(revision, actions, issue)
      user = repo.site.find_user_by_email(revision.cemail) || User.anonymous
      return unless Policies::ApplyHooks.allowed?(user, issue)

      revision_branches = scm.branches(revision.sha).map(&:name)

      all_applicable_hooks.each do |hook|
        if hook.applied_for?(actions, revision_branches)

          repo_revision = repo_revision_by_git_revision(revision)

          hook.apply_for_issue(
              issue,
              :user => user,
              :notes => notes_for_issue_change(repo_revision)
          )

          journal_id = issue.last_journal_id

          repo_revision.applied_hooks.create!(:hook => hook, :issue => issue, :journal_id => journal_id)

          return
        end
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

    def make_references_to_issues(revision, issues)
      issues.each do |issue|

        issue.changesets << self
      end
    end

  end
end
