module RedmineUndevGit::Services
  class ExtRepo
    attr_reader :user, :host, :path_to_repo

    def initialize(repo_url)
      if m = /\A(?<user>.+?)@(?<host>.+?):(?<path_to_repo>.+?)\.git\z/.match(repo_url)
        @user, @host, @path_to_repo = m[:user], m[:host], m[:path_to_repo]
      elsif m = /\Ahttps:\/\/(?<host>.+?)\/(?<path_to_repo>.+?)(\.git)?\z/.match(repo_url)
        @user, @host, @path_to_repo = 'git', m[:host], m[:path_to_repo]
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
end
