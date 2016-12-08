module Workers
  class RemoteRepoFetcher
    @queue = :repository_fetch_queue

    class << self
      def defer(repository_id, operation = :fetch)
        options = { 'id' => repository_id, 'operation' => operation }
        defined?(Resque) ? self.perform_async(options) : perform(options)
      rescue Exception => e
        Rails.logger.debug "RemoteRepoFetcher: #{e.class} => #{e.message}"
        raise
      end

      def perform_async(options)
        Resque.enqueue(Workers::RemoteRepoFetcher, options)
      end

      def perform(options)
        id         = options['id']
        operation  = options['operation'].to_sym
        repository = RemoteRepo.find(id)
        case operation
          when :fetch
            repository.fetch
          when :refetch
            repository.refetch
          else
            raise "Try to perform unknown operation RemoteRepo##{operation}"
        end
      end
    end
  end
end
