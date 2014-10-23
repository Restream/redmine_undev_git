module Workers
  class RemoteRepoFetcher
    @queue = :repository_fetch_queue

    class << self
      def defer(repository_id)
        options = { 'id' => repository_id }
        defined?(Resque) ? self.perform_async(options) : perform(options)
      rescue Exception => e
        Rails.logger.debug "RemoteRepoFetcher: #{e.class} => #{e.message}"
        raise
      end

      def perform_async(options)
        Resque.enqueue(Workers::RemoteRepoFetcher, options)
      end

      def perform(options)
        id = options['id']
        repository = RemoteRepo.find(id)
        repository.fetch
      end
    end
  end
end
