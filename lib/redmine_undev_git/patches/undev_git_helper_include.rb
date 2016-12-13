module RedmineUndevGit
  module Patches
    module UndevGitHelperInclude

      def self.prepended(base)
        base.class_eval do

          helper :undev_git

        end
      end

    end
  end
end
