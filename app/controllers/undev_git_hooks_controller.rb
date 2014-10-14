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

  def push_web_hook_handler(service)
    if service.push_event?
      handle_push_event(service)
    else
      head service.ping_event? ? :ok : :method_not_allowed
    end
  rescue RedmineUndevGit::Services::ServiceError
    head :bad_request
  end

  def handle_push_event(service)
    repos = find_repositories(service.all_urls)
    if repos.any?
      fetch_repositories(repos)
    else
      #todo: check settings - clone or do not clone repos on push web hook
      clone_repository(service.repository_url)
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

  def clone_repository(url)
    #todo
  end
end
