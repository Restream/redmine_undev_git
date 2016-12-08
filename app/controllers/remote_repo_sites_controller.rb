class RemoteRepoSitesController < ApplicationController
  layout 'admin'

  before_filter :require_admin

  helper_method :remote_repo_sites

  def index
  end

  private

  def remote_repo_sites
    @remote_repo_sites ||= RemoteRepoSite.order('server_name')
  end

end
