require 'issues_controller'

module RedmineUndevGit::Patches::IssuesControllerPatch
  extend ActiveSupport::Concern

  included do
    before_filter :read_remote_revisions, only: [:show]

    # authorize remote_revision after find project and issue
    skip_before_filter :authorize, only: [:remove_remote_revision]
    before_filter only: [:remove_remote_revision] { find_issue }
    before_filter only: [:remove_remote_revision] { authorize }
  end

  def remove_remote_revision
    remote_repo = RemoteRepo.find(params[:remote_repo_id])
    rev = remote_repo.find_revision(params[:sha]) || raise(ActiveRecord::RecordNotFound)
    if rev.related_issues.include?(@issue)
      rev.related_issues.delete(@issue)
      flash[:notice] = l(:notice_successful_update)
    end
    redirect_to action: 'show'
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  private

  def read_remote_revisions
    @remote_revisions = @issue.remote_revisions.all
  end

end

unless IssuesController.included_modules.include?(RedmineUndevGit::Patches::IssuesControllerPatch)
  IssuesController.send :include, RedmineUndevGit::Patches::IssuesControllerPatch
end

