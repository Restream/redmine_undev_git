module Policies
  class LogtimeByCommit
    class << self
      def allowed?(user, issue)
        user && user.logged? && issue && user.allowed_to?(:edit_issues, issue.project)
      end
    end
  end
end
