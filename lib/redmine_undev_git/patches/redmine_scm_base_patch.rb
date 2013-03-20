module RedmineUndevGit::Patches
  module RedmineScmBasePatch
    extend ActiveSupport::Concern

    module ClassMethods

      # Inserts the given SCM adapter and Repository before the SCM adapter with the given index.
      def insert(index, scm_name)
        @scms ||= []
        @scms.insert(index, scm_name)
      end

    end
  end
end

unless Redmine::Scm::Base.included_modules.include?(RedmineUndevGit::Patches::RedmineScmBasePatch)
  Redmine::Scm::Base.send :include, RedmineUndevGit::Patches::RedmineScmBasePatch
end
