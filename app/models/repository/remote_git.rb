require_dependency 'redmine/scm/adapters/undev_git_adapter'
require_dependency 'redmine_undev_git/includes/repo_store'
require_dependency 'redmine_undev_git/includes/repo_fetch'
require_dependency 'redmine_undev_git/includes/repo_validate'

class Repository::RemoteGit < Repository

  include RedmineUndevGit::Includes::RepoStore
  include RedmineUndevGit::Includes::RepoValidate
  include RedmineUndevGit::Includes::RepoFetch

  # Hooks from all projects without explicit repository_id
  def hooks
    # TODO
  end

  def supports_directory_revisions?
    false
  end

  def supports_revision_graph?
    false
  end

  def all_applicable_hooks
    hooks.by_position + GlobalHook.by_position
  end

  def use_init_refs?
    false
  end

  def use_init_hooks?
    false
  end

  def fetch_by_web_hook?
    true
  end

  def parent_dir_name
    'REMOTE_GIT_REPOS'
  end
end
