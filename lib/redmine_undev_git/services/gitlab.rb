module RedmineUndevGit::Services
  class GitlabRepo
    attr_reader :user, :host, :path_to_repo

    def initialize(repo_url)
      if m = /\A(?<user>.+?)@(?<host>.+?):(?<path_to_repo>.+?)\.git\z/.match(repo_url)
         @user, @host, @path_to_repo = m[:user], m[:host], m[:path_to_repo]
      else
        raise RedmineUndevGit::Services::WrongRepoUrl
      end
    end

    def git_urls
      [ssh_url, https_url, git_url]
    end

    def ssh_url
      "#{user}@#{host}:#{path_to_repo}.git"
    end

    def https_url
      "https://#{host}/#{path_to_repo}.git"
    end

    def git_url
      "git://#{host}/#{path_to_repo}.git"
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
