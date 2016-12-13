require_dependency 'projects_controller'

module RedmineUndevGit
  module Patches
    module ProjectsControllerPatch

      def self.prepended(base)
        base.class_eval do

          helper :hooks
          helper :custom_fields

        end
      end

    end
  end
end
