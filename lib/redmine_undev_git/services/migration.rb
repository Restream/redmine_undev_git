module RedmineUndevGit
  module Service
    class Migration
      class << self

        SUPPORTED_TYPES = ["Repository::Git", "Repository::UndevGit"]

        ##
        # Reconnect repository
        #
        # @param [Repository::Git, Repository::UndevGit] repository source repository
        # @param [Project] project project in which repository will be created
        # @return [Repository::UndevGit] reconnected repository
        def reconnect_repo_as_undev_git_to(repository, project)
          unless SUPPORTED_TYPES.include? repository.type
            raise ArgumentError, "#{repository} type isn't supported"
          end

          project.enable_module!('repository')

          new_repo = Repository::UndevGit.new
          new_repo.project = project
          new_repo.url = origin_url_of(repository)

          new_repo_id = repository.identifier
          if (project != repository.project)
            new_repo_id = "#{repository.project.identifier}-#{new_repo_id}"
          end

          new_repo.identifier = new_repo_id
          new_repo.is_default = repository.is_default
          new_repo.use_init_hooks = false

          repository.destroy
          new_repo.save!

          new_repo
        end

        private
        def origin_url_of(repository)
          if repository.is_a? Repository::Git
            origin_url = `git config --file '#{File.join( repository.url, "config" )}' --get remote.origin.url`
          else # UndevGit
            origin_url = repository.url
          end

          if origin_url.blank?
            raise RuntimeError, "#{repository.inspect} origin_url is undefined"
          end

          origin_url
        end
      end
    end
  end
end
