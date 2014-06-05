module RedmineUndevGit::Services
  class GithubRepo < ExtRepo
    def git_urls
      [ssh_url, https_url]
    end
  end

  class Github
    PING = 'ping'
    PUSH = 'push'
    EVENTS = [PING, PUSH]

    class << self
      def event(request)
        request.env['HTTP_X_GITHUB_EVENT']
      end

      EVENTS.each do |event|
        define_method "#{event}_event?" do |request|
          event(request) == event
        end
      end

      def git_urls_from_request(request)
        web_hook = web_hook_from_request(request)
        repo = RedmineUndevGit::Services::GithubRepo.new(web_hook['repository']['url'])
        repo.git_urls
      end

      def web_hook_from_request(request)
        JSON.parse(request.body.read)
      end
    end
  end
end
