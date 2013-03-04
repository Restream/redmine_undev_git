require File.expand_path('../../test_helper', __FILE__)

class GlobalHooksControllerTest < ActionController::TestCase
  fixtures :users, :roles, :members, :member_roles, :issue_statuses

  def setup
    @controller = GlobalHooksController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @user = User.find(1) # admin
    User.current = @user
    @request.session[:user_id] = @user.id

    create_hooks!

    @hook = GlobalHook.first
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:hooks)
  end

  def test_permission
    @request.session[:user_id] = 4
    get :index
    assert_response 403

    Role.find(4).add_permission! :edit_global_hooks

    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:hooks)
  end

  def test_get_new
    get :new
    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:hook)
  end

  def test_post_create
    assert_difference 'GlobalHook.count', 1 do
      post :create, :global_hook => {
          :branches => 'Master',
          :keywords => 'closes',
          :new_done_ratio => '50%' }
    end

    assert_redirected_to '/hooks'
  end

  def test_get_edit
    get :edit, :id => @hook.id
    assert_response :success
    assert_template 'edit'
    assert_not_nil assigns(:hook)
  end

  def test_put_update
    assert_no_difference 'GlobalHook.count' do
      put :update, :id => @hook.id, :global_hook => { :branches => 'staging' }
    end

    assert_redirected_to '/hooks'
    @hook.reload
    assert_equal ['staging'], @hook.branches
  end

  def test_post_destroy
    assert_difference 'GlobalHook.count', -1 do
      post :destroy, :id => @hook.id
    end

    assert_redirected_to '/hooks'
    hook = GlobalHook.find_by_id(@hook.id)
    assert_nil hook
  end

  def test_move_higher
    h1 = GlobalHook.by_position[0]
    h2 = GlobalHook.by_position[1]

    assert_equal 1, h1.position
    assert_equal 2, h2.position

    put :update, :id => h2.id, :global_hook => { 'move_to' => 'higher' }

    assert_response :redirect

    h1.reload
    h2.reload

    assert_equal 2, h1.position
    assert_equal 1, h2.position
  end

  def test_move_lower
    h1 = GlobalHook.by_position[0]
    h2 = GlobalHook.by_position[1]

    assert_equal 1, h1.position
    assert_equal 2, h2.position

    put :update, :id => h1.id, :global_hook => { 'move_to' => 'lower' }

    assert_response :redirect

    h1.reload
    h2.reload

    assert_equal 2, h1.position
    assert_equal 1, h2.position
  end
end
