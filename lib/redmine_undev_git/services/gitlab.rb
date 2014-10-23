module RedmineUndevGit::Services
  class Gitlab < RemoteRepo
    def all_urls
      [ssh_url, https_url, git_url]
    end
  end
end
