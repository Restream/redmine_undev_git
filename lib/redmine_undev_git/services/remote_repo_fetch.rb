module RedmineUndevGit::Services
  # fetch remote repository
  class RemoteRepoFetch
    attr_reader :remote_repo

    def initialize(remote_repo)
      @remote_repo = remote_repo
    end

    def fetch

    end
  end
end
