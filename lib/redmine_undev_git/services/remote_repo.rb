module RedmineUndevGit::Services

  # Service to work with webhooks from remote repository storage services
  class RemoteRepo

    def initialize(request)
      @request = request
    end

    def ping_event?
      false
    end

    def push_event?
      true
    end

    def all_urls
      [ssh_url, https_url, git_url]
    end

    def ssh_url
      "#{url_parts[:user]}@#{url_parts[:host]}:#{url_parts[:path_to_repo]}.git"
    end

    def https_url
      "https://#{url_parts[:host]}/#{url_parts[:path_to_repo]}.git"
    end

    def git_url
      "git://#{url_parts[:host]}/#{url_parts[:path_to_repo]}.git"
    end

    def repository_url
      @repository_url ||= web_hook['repository']['url']
    end

    def web_hook
      @web_hook ||= JSON.parse(@request.body.read)
    end

    private

    def url_parts
      @url_parts ||= \
        if m = /\A(?<user>.+?)@(?<host>.+?):(?<path_to_repo>.+?)\.git\z/.match(repository_url)
                               {
                                   :user => m[:user],
                                   :host => m[:host],
                                   :path_to_repo => m[:path_to_repo]
                               }
        elsif m = /\Ahttps:\/\/(?<host>.+?)\/(?<path_to_repo>.+?)(\.git)?\z/.match(repository_url)
          {
              :user => 'git',
              :host => m[:host],
              :path_to_repo => m[:path_to_repo]
          }
        else
          raise RedmineUndevGit::Services::WrongRepoUrl
        end
    end
  end
end
