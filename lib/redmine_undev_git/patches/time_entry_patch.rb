module RedmineUndevGit::Patches
  module TimeEntryPatch
    extend ActiveSupport::Concern

    included do
      belongs_to :remote_repo_revision
    end
  end
end

unless TimeEntry.included_modules.include?(RedmineUndevGit::Patches::TimeEntryPatch)
  TimeEntry.send :include, RedmineUndevGit::Patches::TimeEntryPatch
end
