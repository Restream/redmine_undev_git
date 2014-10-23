module RedmineUndevGit::Services
  class Github < RemoteRepo
    def all_urls
      [ssh_url, https_url]
    end

    def ping_event?
      @request.env['HTTP_X_GITHUB_EVENT'] == 'ping'
    end

    def push_event?
      @request.env['HTTP_X_GITHUB_EVENT'] == 'push'
    end
  end
end
