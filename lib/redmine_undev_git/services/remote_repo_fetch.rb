module RedmineUndevGit::Services
  # fetch remote repository
  class RemoteRepoFetch
    attr_reader :repo

    cattr_accessor :repo_storage_dir
    self.repo_storage_dir = Redmine::Configuration['scm_repo_storage_dir'] || begin
      rpath = Rails.root.join('repos')
      rpath.symlink? ? File.readlink(rpath) : rpath
    end

    def initialize(remote_repo)
      raise ServiceError.new('Fatal: remote_repo is not persisted.') unless remote_repo.persisted?
      @repo = remote_repo
    end

    def fetch
      initialize_repository
      download_changes

      head_revs = head_revisions
      tail_revs = repo.tail_revisions

      # no changes. going home
      return if head_revs == tail_revs

      repo.transaction do

        revisions(head_revs, tail_revs).each do |revision|
          parsed = parse_comments(revision.message)
          link_revision_to_issues(revision, parsed[:ref_issues])

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

    def link_revision_to_issues(revision, ref_issues_ids)
      ref_issues_ids.each do |issue_id|
        issue = Issue.find_by_id(issue_id, :include => :project)
        revision.related_issues << issue if issue
      end
    end

    def download_changes
      scm.fetch!
    end

    def local_path
      @local_path ||= File.join(self.repo_storage_dir, 'REMOTE_REPOS', repo.id.to_s)
    end

    def initialize_repository
      scm.clone_repository unless scm.cloned?
    end

    def scm
      @scm ||= begin
        repo.update_attribute(:root_url, local_path) if repo.root_url.blank?
        Redmine::Scm::Adapters::UndevGitAdapter.new(repo.url, repo.root_url)
      end
    end

    def head_revisions
      scm.branches.map(&:scmid).sort.uniq
    end

    def revisions(include_revs, exclude_revs)
      opts = {}
      opts[:reverse]  = true
      opts[:includes] = include_revs
      opts[:excludes] = exclude_revs

      scm.revisions('', nil, nil, opts)
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

    def all_applicable_hooks
      @all_applicable_hooks ||= ProjectHook.global.by_position + GlobalHook.by_position
    end

    def make_references_to_issues(revision, issues)
      issues.each do |issue|

        issue.changesets << self
      end
    end

  end
end
