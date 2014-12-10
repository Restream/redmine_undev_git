module RedmineUndevGit::Patches
  module ProjectsHelperPatch
    extend ActiveSupport::Concern

    included do
      alias_method_chain :project_settings_tabs, :hooks_tab
    end

    def project_settings_tabs_with_hooks_tab
      tabs = project_settings_tabs_without_hooks_tab
      change_partial_for_repositories_settings_tab(tabs)
      add_project_hooks_settings_tab(tabs)
    end

    def change_partial_for_repositories_settings_tab(tabs)
      tab_repositories_idx = tabs.index { |t| t[:name] == 'repositories' }
      if tab_repositories_idx
        tab_repositories = tabs[tab_repositories_idx]
        tab_repositories[:partial] = 'projects/settings/repositories_with_remotes'
      end
      tabs
    end

    def add_project_hooks_settings_tab(tabs)
      if User.current.allowed_to?(:edit_hooks, @project)
        # add tab after repositories
        tab_repositories_idx = tabs.index { |t| t[:name] == 'repositories' }
        idx                  = tab_repositories_idx ? tab_repositories_idx + 1 : -1
        tabs.insert idx, {
                name:       'hooks',
                controller: 'project_hooks',
                action:     :edit,
                partial:    'project_hooks/index',
                label:      :label_project_hooks_plural
            }
      end
      tabs
    end

    def status_image_tag(repository)
      fetch_status = repository.fetch_status
      icon_image = case fetch_status
                     when :unknown then 'icon-white'
                     when :green then 'icon-green'
                     when :yellow then 'icon-yellow'
                     when :red then 'icon-red'
                     else 'icon-black'
                   end
      label_fetch_status = l("label_fetch_statuses.#{fetch_status}")
      text_fetch_status = [:red, :yellow].include?(fetch_status) ?
          repository.last_fetch_event.error_message :
          l("text_fetch_statuses.#{fetch_status}")
      content_tag :span, label_fetch_status, class: "icon #{icon_image}", title: text_fetch_status
    end
  end
end
