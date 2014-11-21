require 'issues_controller'

module RedmineUndevGit::Patches::IssuesControllerPatch
  extend ActiveSupport::Concern

  included do
    before_filter :read_remote_revisions, :only => [:show]
  end

  def read_remote_revisions
    @remote_revisions = @issue.remote_revisions.all
  end

end

unless IssuesController.included_modules.include?(RedmineUndevGit::Patches::IssuesControllerPatch)
  IssuesController.send :include, RedmineUndevGit::Patches::IssuesControllerPatch
end

