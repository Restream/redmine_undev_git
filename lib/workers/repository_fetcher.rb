module Workers
  class RepositoryFetcher
    @queue = :repository_fetch_queue

    class << self
      def defer(repository_id)
        params = { id: repository_id }
        self.perform_async(params)
      rescue Exception => e
        Rails.logger.debug "RepositoryFetcher: #{e.class} => #{e.message}"
        raise
      end

      def perform_async(options)
        Resque.enqueue(Workers::RepositoryFetcher, options)
      end

      def perform(options)
        id = options['id']
        repository = Repository::UndevGit.find(id)
        repository.fetch_changesets
      end
    end
  end
end

