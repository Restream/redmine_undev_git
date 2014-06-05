module RedmineUndevGit::Services
  class GitlabRepo < ExtRepo
    def git_urls
      [ssh_url, https_url, git_url]
    end
  end

  class Gitlab
    class << self
      def git_urls_from_request(request)
        web_hook = web_hook_from_request(request)
        repo = RedmineUndevGit::Services::GitlabRepo.new(web_hook['repository']['url'])
        repo.git_urls
      end

      def web_hook_from_request(request)
        JSON.parse(request.body.read)
      end
    end
  end
end
