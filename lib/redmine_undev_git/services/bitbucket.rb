module RedmineUndevGit::Services
  class Bitbucket < RemoteRepoService

    private

    def find_or_create_remote_repo_site
      RemoteRepoSite::Bitbucket.first_or_create!(:server_name => server_name)
    end

    def all_urls
      [ssh_url, https_url, https_with_owner_url]
    end

    def https_with_owner_url
      "https://#{url_parts[:repo_owner]}@#{url_parts[:host]}/#{url_parts[:path_to_repo]}.git"
    end

    def repository_url
      https_url
    end

    def web_hook
      @web_hook ||= JSON.parse(@request.params[:payload])
    end

    def url_parts
      @parts ||= begin
        absolute_url, canon_url, repo_owner =
            web_hook['repository']['absolute_url'], web_hook['canon_url'], web_hook['user']

        if m = /\Ahttps?:\/\/(?<host>.+?)\z/.match(canon_url)
          host = m[:host]
        else
          raise RedmineUndevGit::Services::WrongRepoUrl
        end
        if m = /\A\/(?<path_to_repo>.+)\/\z/.match(absolute_url)
          path_to_repo = m[:path_to_repo]
        else
          raise RedmineUndevGit::Services::WrongRepoUrl
        end
        {
            :user => 'git',
            :host => host,
            :path_to_repo => path_to_repo,
            :repo_owner => repo_owner
        }
      end
    end
  end
end
