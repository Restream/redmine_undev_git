module Policies
  class CreateRemoteRepo
    class << self
      def allowed?(repository_url)
        #todo
        true
      end
    end
  end
end
