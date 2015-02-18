class UndevGitHooksController < ActionController::Base

  def gitlab_push
    RedmineUndevGit::Services::Gitlab.handle_request(request)
    head :ok
  end

  def github_push
    RedmineUndevGit::Services::Github.handle_request(request)
    head :ok
  end

  def bitbucket_push
    RedmineUndevGit::Services::Bitbucket.handle_request(request)
    head :ok
  end

end
