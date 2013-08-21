require 'redmine'

raise PluginRequirementError.new(
          "redmine_undev_git plugin requires Ruby 1.9.1 or higher but current is #{RUBY_VERSION}"
      ) unless RUBY_VERSION >= '1.9.1'

Rails.application.paths["app/overrides"] ||= []
Rails.application.paths["app/overrides"] << File.expand_path("../app/overrides", __FILE__)

require 'redmine_undev_git'

Redmine::Plugin.register :redmine_undev_git do
  name        'Redmine UndevGit plugin'
  description 'Git repository with remote repositories and hooks support'
  author      'Denis Diachkov, Vladimir Kiselev, Danil Tashkinov'
  author_url  'https://github.com/Undev'
  version     '0.2.3'
  url         'https://github.com/Undev/redmine_undev_git'

  requires_redmine :version_or_higher => '2.1'

  # Global hooks
  menu :admin_menu,
       :global_hooks,
       { :controller => 'global_hooks', :action => 'index' },
       :html => { :class => 'global_hooks_label' }
  permission :edit_global_hooks,
             { :global_hooks => [:index, :new, :create, :edit, :update, :destroy] },
             :require => :admin

  # Project hooks
  project_module :hooks do
    permission :edit_hooks,
               { :project_hooks => [:new, :create, :edit, :update, :destroy] },
               :require => :member
  end

  # Plugin settings
  settings :partial => 'settings/undev_git_settings',
           :default => {
               :max_branches_in_assoc => 5
           }
end

Redmine::Scm::Base.insert 0, 'UndevGit'
