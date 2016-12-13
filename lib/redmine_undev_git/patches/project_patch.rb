require_dependency 'project'

module RedmineUndevGit
  module Patches
    module ProjectPatch

      def self.prepended(base)
        base.class_eval do

          has_many :hooks, class_name: 'ProjectHook'

        end
      end

      def remote_repositories
        RemoteRepo.related_to_project(self)
      end

    end
  end
end
