module RedmineUndevGit::Patches
  module ProjectsHelperPatch
    extend ActiveSupport::Concern

    included do
      alias_method_chain :project_settings_tabs, :hooks_tab
    end

    def project_settings_tabs_with_hooks_tab
      tabs = project_settings_tabs_without_hooks_tab

      # check permissions
      if User.current.allowed_to?(:edit_hooks, @project)
        # add tab after repositories
        i = tabs.index { |t| t[:name] == 'repositories' }
        tabs.insert i ? i + 1 : -1, {
            :name       => 'hooks',
            :controller => 'project_hooks',
            :action     => :edit,
            :partial    => 'project_hooks/index',
            :label      => :label_project_hooks_plural
        }
      end

      tabs
    end
  end
end

unless ProjectsHelper.included_modules.include?(RedmineUndevGit::Patches::ProjectsHelperPatch)
  ProjectsHelper.send :include, RedmineUndevGit::Patches::ProjectsHelperPatch
end

