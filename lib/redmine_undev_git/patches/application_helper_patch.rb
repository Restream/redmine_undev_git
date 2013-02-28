module RedmineUndevGit::Patches
  module ApplicationHelperPatch
    extend ActiveSupport::Concern

    include RedmineUndevGit::Helpers::UndevGitHelper

  end
end

unless ApplicationHelper.included_modules.include?(RedmineUndevGit::Patches::ApplicationHelperPatch)
  ApplicationHelper.send :include, RedmineUndevGit::Patches::ApplicationHelperPatch
end

