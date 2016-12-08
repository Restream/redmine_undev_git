require File.expand_path('../../test_helper', __FILE__)

class ProjectHooksControllerTest < ActionController::TestCase
  fixtures :projects, :repositories, :users, :email_addresses,
    :roles, :members, :member_roles

  def setup
    make_temp_dir
    @controller                = ProjectHooksController.new
    @request                   = ActionController::TestRequest.new
    @response                  = ActionController::TestResponse.new
    @request.session[:user_id] = 1 # admin

    @project                      = Project.find(3)
    @project.enabled_module_names = [:repository, :hooks]
    @project.save!

    Setting.enabled_scm << 'UndevGit'

    repo = create_test_repository(
      identifier: 'test',
      project:    @project
    )

    create_hooks!(repository_id: repo.id)

    @repository_hook = ProjectHook.first
  end

  def teardown
    remove_temp_dir
  end

  def test_permission
    @request.session[:user_id] = 4
    get :new, project_id: @project.id
    assert_response 403

    Role.find(4).add_permission! :edit_hooks

    get :new, project_id: @project.id
    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:hook)
  end

  def test_get_new
    get :new, project_id: @project.id
    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:hook)
  end

  def test_post_create
    assert_difference 'ProjectHook.count', 1 do
      post :create, project_id: @project.id,
        project_hook:           {
          branches:   'Master',
          keywords:   'closes',
          done_ratio: '50'
        }
    end

    assert_response :redirect
  end

  def test_get_edit
    get :edit, id: @repository_hook.id, project_id: @project.id
    assert_response :success
    assert_template 'edit'
    assert_not_nil assigns(:hook)
  end

  def test_put_update
    assert_not_nil @repository_hook.repository_id
    assert_not_equal @repository_hook, 'staging'

    assert_no_difference 'ProjectHook.count' do
      put :update, id: @repository_hook.id, project_id: @project.id,
        project_hook:  { branches: 'staging', repository_id: nil }
    end

    @repository_hook.reload

    assert_response :redirect
    assert_equal ['staging'], @repository_hook.branches
    assert_nil @repository_hook.repository_id
  end

  def test_post_destroy
    assert_difference 'ProjectHook.count', -1 do
      post :destroy, id: @repository_hook.id, project_id: @project
    end

    assert_response :redirect

    hook = ProjectHook.find_by_id(@repository_hook.id)
    assert_nil hook
  end
end
