require_dependency 'redmine/scm/base'

module RedmineUndevGit
  module Patches
    module RedmineScmBasePatch

      def self.prepended(base)
        base.class_eval do

          extend ClassMethods

        end
      end

      module ClassMethods

        # Inserts the given SCM adapter and Repository before the SCM adapter with the given index.
        def insert(index, scm_name)
          @scms ||= []
          @scms.insert(index, scm_name)
        end

      end
    end
  end
end
