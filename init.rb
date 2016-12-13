require 'redmine'

Rails.application.paths['app/overrides'] ||= []
Rails.application.paths['app/overrides'] << File.expand_path('../app/overrides', __FILE__)

Redmine::Plugin.register :redmine_undev_git do
  name 'Redmine UndevGit Plugin'
  description 'This plugin adds a new Git repository type that supports hooks and remote repositories.'
  author 'Restream'
  author_url 'https://github.com/Restream'
  version '0.3.0'
  url 'https://github.com/Restream/redmine_undev_git'

  requires_redmine version_or_higher: '3.1'

  # Global hooks
  menu :admin_menu,
    :global_hooks,
    { controller: 'global_hooks', action: 'index' },
    html: { class: 'global_hooks_label' }
  permission :edit_global_hooks,
    { global_hooks: [:index, :new, :create, :edit, :update, :destroy] },
    require: :admin

  # Project hooks
  project_module :hooks do
    permission :edit_hooks,
      { project_hooks: [:new, :create, :edit, :update, :destroy] },
      require: :member
  end

  # Plugin settings
  settings partial: 'settings/undev_git_settings',
    default:        {
      max_branches_in_assoc: 5,
      fetch_by_web_hook:     '0'
    }

  # Remote repositories
  menu :admin_menu,
    :remote_repo_sites,
    { controller: 'remote_repo_sites', action: 'index' },
    html: { class: 'remote_repo_sites_label' }
  permission :edit_remote_repo_sites,
    { remote_repo_sites: [:index, :show] },
    require: :admin

  # permission for custom buttons the same as :edit_issues
  Redmine::AccessControl.permission(:manage_related_issues).actions.push *%w{
      issues/remove_remote_revision
  }

end

require 'redmine_undev_git'

# Add UndevGit SCM adapter and repository
Redmine::Scm::Base.add 'UndevGit'
