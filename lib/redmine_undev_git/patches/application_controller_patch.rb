require 'application_controller'

module RedmineUndevGit::Patches::ApplicationControllerPatch
  extend ActiveSupport::Concern

  included do
    lazy_helper :undev_git
    lazy_helper RedmineUndevGit::Patches::ProjectsHelperPatch, if_included: ProjectsHelper
  end

end

unless ApplicationController.included_modules.include?(RedmineUndevGit::Patches::ApplicationControllerPatch)
  ApplicationController.send :include, RedmineUndevGit::Patches::ApplicationControllerPatch
end

