module RedmineUndevGit::Services
  class Github < RemoteRepo

    private

    def find_or_create_remote_repo_site
      RemoteRepoSite::Github.first_or_create!(:server_name => server_name)
    end

    def all_urls
      [ssh_url, https_url]
    end

    def push_event?
      @request.env['HTTP_X_GITHUB_EVENT'] == 'push'
    end
  end
end
