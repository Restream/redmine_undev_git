class UndevGitHooksController < ActionController::Base

  def gitlab_push
    push_web_hook_handler RedmineUndevGit::Services::Gitlab.new(request)
  end

  def github_push
    push_web_hook_handler RedmineUndevGit::Services::Github.new(request)
  end

  def bitbucket_push
    push_web_hook_handler RedmineUndevGit::Services::Bitbucket.new(request)
  end

  private

  def push_web_hook_handler(hook_service)
    if hook_service.push_event?
      handle_push_event(hook_service)
    else
      head hook_service.ping_event? ? :ok : :method_not_allowed
    end
  rescue RedmineUndevGit::Services::ServiceError
    head :bad_request
  end

  def handle_push_event(hook_service)
    repos = find_repositories(hook_service.all_urls)
    if repos.any?
      fetch_repositories(repos)
    else
      #todo: check settings - clone or do not clone repos on push web hook
      create_remote_repo(hook_service)
    end
    head :ok
  end

  def fetch_repositories(repos)
    repos.each do |repo|
      Workers::RepositoryFetcher.defer(repo.id) if RedmineUndevGit.fetch_by_web_hook? || repo.fetch_by_web_hook?
    end
  end

  def find_repositories(urls)
    Repository::UndevGit.where('url in (?)', urls)
  end

  def create_remote_repo(hook_service)
    repo_service = repo_service_by_hook_service(hook_service)
    repo = repo_service.repos.create!(:url => hook_service.repository_url)
    Workers::RemoteRepoFetcher.defer(repo.id)
  end

  def repo_service_by_hook_service(hook_service)
    repo_service = RemoteRepoSite.find_by_server_name(hook_service.server_name)
    unless repo_service
      repo_service_class = "RemoteRepoSite::#{hook_service.class_name}".constantize
      repo_service_class.create!(:server_name => hook_service.server_name)
    end
    repo_service
  end
end
