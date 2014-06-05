module RedmineUndevGit::Patches
  module RepositoryPatch
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :fetch_changesets, :web_hooks
      end
    end

    module ClassMethods
      def fetch_changesets_with_web_hooks
        Project.active.has_module(:repository).all.each do |project|
          project.repositories.each do |repository|
            begin
              if self.fetch_by_web_hook?(repository)
                logger.warning "Repository #{repository.url} skipped because it's fetch by web hooks."
              else
                repository.fetch_changesets
              end
            rescue Redmine::Scm::Adapters::CommandFailed => e
              logger.error "scm: error during fetching changesets: #{e.message} #{repository.url}"
            rescue Exception => e
              logger.error "Unknown error during fetching changesets: #{e.message} #{repository.url}"
            end
          end
        end
      end

      def self.fetch_by_web_hook?(repository)
        repository.respond_to?(:fetch_by_web_hook?) && (
            RedmineUndevGit.fetch_by_web_hook? || repository.fetch_by_web_hook?
        )
      end
    end
  end
end

unless Repository.included_modules.include?(RedmineUndevGit::Patches::RepositoryPatch)
  Repository.send :include, RedmineUndevGit::Patches::RepositoryPatch
end
