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
      raise 'Fatal: remote_repo is not persisted.' unless remote_repo.persisted?
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
           # parse revision
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
      opts[:excludes] = prev_db_heads
      opts[:includes] = repo_heads

      scm.revisions('', nil, nil, opts)
    end

  end
end
