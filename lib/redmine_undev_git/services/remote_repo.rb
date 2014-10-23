module RedmineUndevGit::Services

  # Service to work with webhooks from remote repository storage services
  class RemoteRepo

    class << self
      def handle_request(request)
        service = self.new(request)
        service.handle_push_event if service.push_event?
      end
    end

    def initialize(request)
      @request = request
    end

    private

    def handle_push_event
      repos = find_repositories
      if repos.any?
        fetch_repositories(repos)
      else
        remote_repo = find_remote_repository || try_to_create_remote_repository
        fetch_remote_repository(remote_repo) if remote_repo
      end
    end

    def find_repositories
      Repository::UndevGit.where('url in (?)', all_urls)
    end

    def fetch_repositories(repos)
      repos.each do |repo|
        Workers::RepositoryFetcher.defer(repo.id) if RedmineUndevGit.fetch_by_web_hook? || repo.fetch_by_web_hook?
      end
    end

    def find_remote_repository
      RemoteRepo.find_by_url(repository_url)
    end

    def try_to_create_remote_repository
      return nil unless Policies::CreateRemoteRepo.allowed?(repository_url)
      remote_repo_site = find_or_create_remote_repo_site
      remote_repo_site.repos.create!(:url => repository_url)
    end

    def fetch_remote_repository(remote_repo)
      Workers::RemoteRepoFetcher.defer(remote_repo.id)
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

    def server_name
      url_parts[:host]
    end

    def repository_url
      @repository_url ||= web_hook['repository']['url']
    end

    def web_hook
      @web_hook ||= JSON.parse(@request.body.read)
    end

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
