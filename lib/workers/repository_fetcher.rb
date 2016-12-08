module Workers
  class RepositoryFetcher
    @queue = :repository_fetch_queue

    class << self
      def defer(repository_id)
        options = { 'id' => repository_id }
        defined?(Resque) ? self.perform_async(options) : perform(options)
      rescue Exception => e
        Rails.logger.debug "RepositoryFetcher: #{e.class} => #{e.message}"
        raise
      end

      def perform_async(options)
        Resque.enqueue(Workers::RepositoryFetcher, options)
      end

      def perform(options)
        id         = options['id']
        repository = Repository::UndevGit.find(id)
        repository.fetch_changesets
      end
    end
  end
end

