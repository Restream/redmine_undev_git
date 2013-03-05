module RedmineUndevGit
end

require 'redmine_undev_git/patches/string_patch'
require 'redmine_undev_git/patches/project_patch'
require 'redmine_undev_git/patches/changeset_patch'

require 'redmine_undev_git/helpers/undev_git_helper'

require 'redmine_undev_git/patches/application_helper_patch'
require 'redmine_undev_git/patches/repositories_helper_patch'
require 'redmine_undev_git/patches/projects_helper_patch'

require 'redmine_undev_git/hooks/view_hooks'

require 'redmine_undev_git/services/migration'
