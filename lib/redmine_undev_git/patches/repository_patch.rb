module RedmineUndevGit::Patches
  module RepositoryPatch
    extend ActiveSupport::Concern

    included do
      KEEP_FETCH_EVENTS = 100
      RED_STATUS_THRESHOLD = 3

      has_many :fetch_events, :dependent => :delete_all

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

      def fetch_by_web_hook?(repository)
        repository.respond_to?(:fetch_by_web_hook?) && (
            RedmineUndevGit.fetch_by_web_hook? || repository.fetch_by_web_hook?
        )
      end
    end

    def cleanup_fetch_events(keep = KEEP_FETCH_EVENTS)
      return unless persisted?
      last_ids = fetch_events.sorted.limit(keep).pluck(:id)
      return 0 if last_ids.count < keep
      FetchEvent.delete_all(['repository_id = ? and id < ?', id, last_ids.min])
    end

    # should returns :unknown, :green, :yellow or :red status
    def fetch_status
      :unknown
    end

    def fetch_successful?
      last_fetch_event.try(:successful?)
    end

    def last_fetch_event
      fetch_events.sorted.first
    end
  end
end

unless Repository.included_modules.include?(RedmineUndevGit::Patches::RepositoryPatch)
  Repository.send :include, RedmineUndevGit::Patches::RepositoryPatch
end
