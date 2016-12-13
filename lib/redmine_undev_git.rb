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
    settings                         = Setting.plugin_redmine_undev_git
    settings[:fetch_by_web_hook]     = value
    Setting.plugin_redmine_undev_git = settings
  end

  def self.prepend_patch(patch, *targets)
    targets = Array(targets).flatten
    targets.each do |target|
      unless target.included_modules.include? patch
        target.prepend patch
      end
    end
  end

end

# Require all dependencies
Dir[File.join(__dir__, 'redmine_undev_git/**/*.rb')].each do |fn|
  require_dependency fn
end

# Apply patches
ActionDispatch::Callbacks.to_prepare do
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::ProjectPatch, Project
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::IssuePatch, Issue
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::ChangesetPatch, Changeset
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::TimeEntryPatch, TimeEntry
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::RepositoryPatch, Repository
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::UndevGitHelperInclude,
    IssuesController, RepositoriesController
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::ProjectsControllerPatch, ProjectsController
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::IssuesControllerPatch, IssuesController
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::RepositoriesControllerPatch, RepositoriesController
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::ProjectsHelperPatch,
    CalendarsController, GanttsController, IssuesController, VersionsController, ProjectsController
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::RedmineScmBasePatch, Redmine::Scm::Base
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::CustomFieldPatch, CustomField
  RedmineUndevGit.prepend_patch RedmineUndevGit::Patches::CustomFieldValuePatch, CustomFieldValue
end
