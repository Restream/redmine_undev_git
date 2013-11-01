class ProjectHooksController < ApplicationController

  before_filter :find_project_by_project_id
  before_filter :authorize

  helper :sort
  include SortHelper
  helper :hooks
  helper :custom_fields

  def new
    @hook = @project.hooks.build
  end

  def create
    @hook = @project.hooks.build(params[:project_hook])

    if @hook.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to_settings_in_projects
    else
      render :action => 'new'
    end
  end

  def update
    @hook = @project.hooks.find(params[:id])
    if @hook.update_attributes(params[:project_hook])
      flash[:notice] = l(:notice_successful_update)
      redirect_to_settings_in_projects
    else
      render :action => 'edit'
    end
  end

  def edit
    @hook = @project.hooks.find(params[:id])
  end

  def destroy
    hook = @project.hooks.find(params[:id])
    hook.destroy

    flash[:notice] = l(:notice_successful_delete)
    redirect_to_settings_in_projects
  end

  private

  def redirect_to_settings_in_projects
    redirect_to settings_project_path(@project, :tab => :hooks)
  end
end
