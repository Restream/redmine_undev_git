require_dependency 'repository'

class Repository < ActiveRecord::Base
  KEEP_FETCH_EVENTS    = 100
  RED_STATUS_THRESHOLD = 3
end

module RedmineUndevGit
  module Patches
    module RepositoryPatch

      def self.prepended(base)
        base.class_eval do

          has_many :fetch_events, dependent: :delete_all

          class << base
            prepend ClassMethods
          end

        end
      end

      module ClassMethods
        def fetch_changesets
          Project.active.has_module(:repository).each do |project|
            project.repositories.each do |repository|
              begin
                if self.fetch_by_web_hook?(repository)
                  logger.warn "Repository #{repository.url} skipped because it's fetch by web hooks."
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
          repository.respond_to?(:fetch_by_web_hook?) &&
            (RedmineUndevGit.fetch_by_web_hook? || repository.fetch_by_web_hook?)
        end
      end

      def cleanup_fetch_events(keep = nil)
        return unless persisted?
        keep     ||= Repository::KEEP_FETCH_EVENTS
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
end
