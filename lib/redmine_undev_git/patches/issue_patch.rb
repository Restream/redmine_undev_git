require_dependency 'issue'

module RedmineUndevGit
  module Patches
    module IssuePatch

      def self.prepended(base)
        base.class_eval do

          has_and_belongs_to_many :remote_revisions,
            class_name: 'RemoteRepoRevision',
            join_table: 'remote_repo_related_issues'

          has_many :applied_hooks, class_name: 'RemoteRepoHook', dependent: :delete_all

        end
      end

    end
  end
end
