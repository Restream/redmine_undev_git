module RedmineUndevGit::Patches
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      has_and_belongs_to_many :remote_revisions,
                              :class_name => 'RemoteRepoRevision',
                              :join_table => 'remote_repo_related_issues'

      has_many :applied_hooks, :class_name => 'RemoteRepoHook', :dependent => :delete_all

    end
  end
end

unless Issue.included_modules.include?(RedmineUndevGit::Patches::IssuePatch)
  Issue.send :include, RedmineUndevGit::Patches::IssuePatch
end
