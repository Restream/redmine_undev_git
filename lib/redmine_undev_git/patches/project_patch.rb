module RedmineUndevGit::Patches
  module ProjectPatch
    extend ActiveSupport::Concern

    included do
      has_many :hooks, class_name: 'ProjectHook'
    end

    def remote_repositories
      RemoteRepo.related_to_project(self)
    end
  end
end

unless Project.included_modules.include?(RedmineUndevGit::Patches::ProjectPatch)
  Project.send :include, RedmineUndevGit::Patches::ProjectPatch
end
