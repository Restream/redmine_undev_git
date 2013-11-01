require 'projects_controller'

module RedmineUndevGit::Patches::ProjectsControllerPatch
  extend ActiveSupport::Concern

  included do
    before_filter :check_hooks_helper_included
  end

  # A way to make plugin helpers available
  def check_hooks_helper_included
    self.class.helper(:hooks) unless _helpers.included_modules.include?(HooksHelper)
    self.class.helper(:custom_fields) unless _helpers.included_modules.include?(CustomFieldsHelper)
    true
  end

end

unless ProjectsController.included_modules.include?(RedmineUndevGit::Patches::ProjectsControllerPatch)
  ProjectsController.send :include, RedmineUndevGit::Patches::ProjectsControllerPatch
end

