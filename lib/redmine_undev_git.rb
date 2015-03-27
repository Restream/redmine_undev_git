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

require 'lazy_helpers'

require 'redmine_undev_git/patches/string_patch'
require 'redmine_undev_git/patches/project_patch'
require 'redmine_undev_git/patches/issue_patch'
require 'redmine_undev_git/patches/changeset_patch'
require 'redmine_undev_git/patches/time_entry_patch'

require 'redmine_undev_git/patches/projects_controller_patch'
require 'redmine_undev_git/patches/repository_patch'
require 'redmine_undev_git/patches/issues_controller_patch'
require 'redmine_undev_git/patches/repositories_controller_patch'
require 'redmine_undev_git/patches/application_controller_patch'

require 'redmine_undev_git/hooks/view_hooks'

require 'redmine_undev_git/services/migration'
require 'redmine_undev_git/services/errors'
require 'redmine_undev_git/services/git_adapter'
require 'redmine_undev_git/services/remote_repo_service'
require 'redmine_undev_git/services/remote_repo_fetch'
require 'redmine_undev_git/services/gitlab'
require 'redmine_undev_git/services/github'
require 'redmine_undev_git/services/bitbucket'

require 'redmine_undev_git/patches/redmine_scm_base_patch'
require 'redmine_undev_git/patches/custom_field_patch'
require 'redmine_undev_git/patches/custom_field_value_patch'

require 'redmine_undev_git/includes/repo_fetch'
require 'redmine_undev_git/includes/repo_hooks'
require 'redmine_undev_git/includes/repo_store'
require 'redmine_undev_git/includes/repo_validate'
