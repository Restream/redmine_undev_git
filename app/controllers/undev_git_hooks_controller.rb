class UndevGitHooksController < ApplicationController

  def gitlab_push
    urls = RedmineUndevGit::Services::Gitlab.git_urls_from_request(request)
    fetch_repositories(urls)
    head :ok
  rescue RedmineUndevGit::Services::ServiceError
    head :bad_request
  end

  private

  def fetch_repositories(urls)
    Repository::UndevGit.where('url in (?)', urls).each do |repo|
      Workers::RepositoryFetcher.defer(repo.id) if RedmineUndevGit.fetch_by_web_hook? || repo.fetch_by_web_hook?
    end
  end

end
