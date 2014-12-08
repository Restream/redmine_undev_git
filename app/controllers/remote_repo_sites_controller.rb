class RemoteRepoSitesController < ApplicationController
  before_filter :authorize_global

  layout 'admin'

  helper_method :remote_repo_sites
  helper_method :remote_repo_site

  def index
  end

  def show
    @remote_repo_site = RemoteRepoSite.find(params[:id])
  end

  private

  attr_reader :remote_repo_site

  def remote_repo_sites
    @remote_repo_sites ||= RemoteRepoSite.all
  end

end
