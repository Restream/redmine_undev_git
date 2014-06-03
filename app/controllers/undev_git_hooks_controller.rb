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
    Repository::UndevGit.where('url in (?)', urls).pluck(:id).each do |repo_id|
      Workers::RepositoryFetcher.defer repo_id
    end
  end

end
