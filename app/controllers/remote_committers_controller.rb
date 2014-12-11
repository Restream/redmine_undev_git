class RemoteCommittersController < ApplicationController
  layout 'admin'

  before_filter :require_admin

  helper_method :remote_repo_site
  helper_method :committers
  helper_method :users

  def index
  end

  def create
    if params[:committers].is_a?(Hash)
      params[:committers].values.each do |email, user_id|
        remote_repo_site.update_user_mapping(email, user_id)
      end
      flash[:notice] = l(:text_remote_user_mappings_updated)
    end
    redirect_to action: 'index'
  end

  private

  def remote_repo_site
    @remote_repo_site ||= RemoteRepoSite.find(params[:remote_repo_site_id])
  end

  def committers
    @committers ||= remote_repo_site.all_committers_with_mappings
  end

  def users
    @users ||= User.sorted
  end
end
