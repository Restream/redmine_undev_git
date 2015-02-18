module Policies
  class ReferenceToIssue
    class << self

      # When commit will be associated with issue
      #
      # Allow referencing to issue any user
      def allowed?(user, issue)
        !!issue
      end
    end
  end
end
