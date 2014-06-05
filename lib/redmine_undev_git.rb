module RedmineUndevGit
  def self.max_branches_in_assoc
    Setting.plugin_redmine_undev_git[:max_branches_in_assoc].to_i
  end

  def self.fetch_by_web_hook?
    Setting.plugin_redmine_undev_git[:fetch_by_web_hook].to_i > 0
  end

  def self.fetch_by_web_hook
    Setting.plugin_redmine_undev_git[:fetch_by_web_hook]
  end

  def self.fetch_by_web_hook=(value)
    settings = Setting.plugin_redmine_undev_git
    settings[:fetch_by_web_hook] = value
    Setting.plugin_redmine_undev_git = settings
  end
end

require 'redmine_undev_git/patches/string_patch'
require 'redmine_undev_git/patches/project_patch'
require 'redmine_undev_git/patches/changeset_patch'

require 'redmine_undev_git/helpers/undev_git_helper'

require 'redmine_undev_git/patches/application_helper_patch'
require 'redmine_undev_git/patches/repositories_helper_patch'
require 'redmine_undev_git/patches/projects_helper_patch'
require 'redmine_undev_git/patches/projects_controller_patch'
require 'redmine_undev_git/patches/repository_patch'

require 'redmine_undev_git/hooks/view_hooks'

require 'redmine_undev_git/services/errors'
require 'redmine_undev_git/services/migration'
require 'redmine_undev_git/services/gitlab'

require 'redmine_undev_git/patches/redmine_scm_base_patch'
require 'redmine_undev_git/patches/custom_field_patch'
require 'redmine_undev_git/patches/custom_field_value_patch'
