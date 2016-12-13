# Prepend this module to all controllers where ProjectsHelper should be patched
module RedmineUndevGit
  module Patches
    module ProjectsHelperPatch

      def self.prepended(base)
        base.class_eval do

          helper UndevGitProjectsHelper

        end
      end

    end
  end
end
