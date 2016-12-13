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
    @hook = @project.hooks.build(project_hook_params)
    cfv   = params[:project_hook][:custom_field_values]
    if cfv
      @hook.reset_custom_values!
      @hook.custom_field_values = cfv
    end
    if @hook.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to_settings_in_projects
    else
      render action: 'new'
    end
  end

  def update
    @hook = @project.hooks.find(params[:id])
    if @hook.update_attributes(project_hook_params_with_cfv)
      flash[:notice] = l(:notice_successful_update)
      redirect_to_settings_in_projects
    else
      render action: 'edit'
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
    redirect_to settings_project_path(@project, tab: :hooks)
  end

  def project_hook_params
    params.required(:project_hook).
      permit(:branches, :keywords, :status_id, :done_ratio, :assignee_type, :assigned_to_id)
  end

  def project_hook_params_with_cfv
    params.required(:project_hook).
      permit(:branches, :keywords, :status_id, :done_ratio, :assignee_type,
        :assigned_to_id, :custom_field_values, :move_to)
  end
end
