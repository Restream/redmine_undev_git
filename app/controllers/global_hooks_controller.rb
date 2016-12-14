class GlobalHooksController < ApplicationController

  before_filter :authorize_global

  layout 'admin'

  helper :sort
  include SortHelper
  helper :hooks
  helper :custom_fields

  def index
    @hooks = GlobalHook.by_position
  end

  def new
    @hook = GlobalHook.new
  end

  def create
    @hook = GlobalHook.new(global_hook_params)

    if @hook.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to action: 'index'
    else
      render action: 'new'
    end
  end

  def edit
    @hook = GlobalHook.find(params[:id])
  end

  def update
    @hook = GlobalHook.find(params[:id])
    if @hook.update_attributes(global_hook_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to action: 'index'
    else
      render action: 'edit'
    end
  end

  def destroy
    hook = GlobalHook.find(params[:id])
    hook.destroy

    flash[:notice] = l(:notice_successful_delete)
    redirect_to action: 'index'
  end

  private

  def global_hook_params
    params.required(:global_hook).
      permit(:branches, :keywords, :status_id, :done_ratio, :assignee_type,
             :assigned_to_id, :move_to)
  end
end
