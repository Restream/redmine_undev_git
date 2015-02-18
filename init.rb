require 'redmine'

raise(
    PluginRequirementError,
    "redmine_undev_git plugin requires Ruby 1.9.1 or higher but current is #{RUBY_VERSION}"
) unless RUBY_VERSION >= '1.9.1'

raise(
    PluginRequirementError,
    'redmine_undev_git plugin requires git version 1.7.2 or higher'
) unless RedmineUndevGit::Services::GitAdapter.git_version >= '1.7.2'

Rails.application.paths['app/overrides'] ||= []
Rails.application.paths['app/overrides'] << File.expand_path('../app/overrides', __FILE__)

require 'redmine_undev_git'

Redmine::Plugin.register :redmine_undev_git do
  name        'Redmine UndevGit plugin'
  description 'This plugin adds a new Git repository type taht supports remote repositories and hooks'
  author      'Undev'
  author_url  'https://github.com/Undev'
  version     '0.2.9'
  url         'https://github.com/Undev/redmine_undev_git'

  requires_redmine version_or_higher: '2.1'

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
           default: {
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

Redmine::Scm::Base.insert 0, 'UndevGit'
