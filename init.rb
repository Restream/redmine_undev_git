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
  version     '0.0.1'
  url         'https://bitbucket.org/nodecarter/redmine_undev_git'

  requires_redmine :version_or_higher => '2.1'

  ## Global hooks
  #menu :admin_menu, :global_hooks, { :controller => 'hooks', :action => 'index' }
  #
  #global_permissions = [
  #  :index,
  #  :new,
  #  :create,
  #  :edit,
  #  :update,
  #  :destroy
  #]
  #permission :edit_global_hooks, { :hooks => global_permissions },
  #  :require => :member
  #
  ## Project hooks
  #project_permissions = [
  #   :new,
  #   :create,
  #   :edit,
  #   :update,
  #   :destroy
  #]
  #project_module :hooks do
  #  permission :edit_hooks, { :project_hooks => project_permissions },
  #    :require => :member
  #end

  settings(:partial => 'settings/undev_git_settings',
           :default => {
               :max_branches_in_assoc => 5
           })
end

Redmine::Scm::Base.add 'UndevGit'

#require "redmine_undev_curse/cast_helper"
#
#ActionDispatch::Callbacks.to_prepare  do
#  cast RedmineUndevCurse::SpellBook::JournalEnchantment, :on => Journal
#  cast RedmineUndevCurse::SpellBook::ProjectsHelperEnchantment, :on => ProjectsHelper
#  cast RedmineUndevCurse::SpellBook::ProjectEnchantment, :on => Project
#  cast RedmineUndevCurse::SpellBook::RepositoriesHelperEnchantment, :on => RepositoriesHelper
#  cast RedmineUndevCurse::SpellBook::RepositoryEnchantment, :on => Repository
#  cast RedmineUndevCurse::SpellBook::ChangesetEnchantment, :on => Changeset
#  cast RedmineUndevCurse::SpellBook::RepositoriesControllerEnchantment, :on => RepositoriesController
#end
