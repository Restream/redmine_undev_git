require_dependency 'repositories_controller'

module RedmineUndevGit
  module Patches
    module RepositoriesControllerPatch

      # Override redmine show method
      def show
        begin
          @repository.fetch_changesets if Setting.autofetch_changesets? && @path.empty?
        rescue
        end

        @entries   = @repository.entries(@path, @rev)
        @changeset = @repository.find_changeset_by_name(@rev)
        if request.xhr?
          @entries ? render(partial: 'dir_list_content') : render(nothing: true)
        else
          @changesets   = @repository.latest_changesets(@path, @rev)
          @properties   = @repository.properties(@path, @rev)
          @repositories = @project.repositories
          render action: 'show'
        end
      end

    end
  end
end
