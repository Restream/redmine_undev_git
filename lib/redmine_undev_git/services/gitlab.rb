module RedmineUndevGit::Services
  class Gitlab < RemoteRepo

    private

    def find_or_create_remote_repo_site
      RemoteRepoSite::Gitlab.first_or_create!(:server_name => server_name)
    end

    def all_urls
      [ssh_url, https_url, git_url]
    end
  end
end
