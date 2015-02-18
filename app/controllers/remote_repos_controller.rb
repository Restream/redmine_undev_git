class RemoteReposController < ApplicationController
  layout 'admin'

  before_filter :require_admin

  def refetch
    Workers::RemoteRepoFetcher.defer(remote_repo.id, :refetch)
    flash[:notice] = l(:notice_refetch_started)
    redirect_to remote_repo_sites_path
  end

  private

  def remote_repo_site
    @remote_repo_site ||= RemoteRepoSite.find(params[:remote_repo_site_id])
  end

  def remote_repo
    @remote_repo ||= remote_repo_site.repos.find(params[:id])
  end
end
