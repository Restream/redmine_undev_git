require 'projects_controller'

module RedmineUndevGit::Patches::ProjectsControllerPatch
  extend ActiveSupport::Concern

  included do
    lazy_helper :hooks
    lazy_helper :custom_fields
  end

end

unless ProjectsController.included_modules.include?(RedmineUndevGit::Patches::ProjectsControllerPatch)
  ProjectsController.send :include, RedmineUndevGit::Patches::ProjectsControllerPatch
end

