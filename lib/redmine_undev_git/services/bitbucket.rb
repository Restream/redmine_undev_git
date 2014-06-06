module RedmineUndevGit::Services
  class BitbucketRepo < ExtRepo
    attr_reader :repo_owner
    def initialize(absolute_url, canon_url, repo_owner)
      if m = /\Ahttps?:\/\/(?<host>.+?)\z/.match(canon_url)
        @host = m[:host]
      else
        raise RedmineUndevGit::Services::WrongRepoUrl
      end
      if m = /\A\/(?<path_to_repo>.+)\/\z/.match(absolute_url)
        @path_to_repo = m[:path_to_repo]
      else
        raise RedmineUndevGit::Services::WrongRepoUrl
      end
      @user = 'git'
      @repo_owner = repo_owner
    end

    def git_urls
      [ssh_url, https_url, https_with_owner_url]
    end

    def https_with_owner_url
      "https://#{repo_owner}@#{host}/#{path_to_repo}.git"
    end
  end

  class Bitbucket
    class << self
      def git_urls_from_request(request)
        web_hook = web_hook_from_request(request)
        repo = RedmineUndevGit::Services::BitbucketRepo.new(
            web_hook['repository']['absolute_url'], web_hook['canon_url'], web_hook['user'])
        repo.git_urls
      end

      def web_hook_from_request(request)
        JSON.parse(request.params[:payload])
      end
    end
  end
end
