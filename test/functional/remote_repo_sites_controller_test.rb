require File.expand_path('../../test_helper', __FILE__)

class RemoteRepoSitesControllerTest < ActionController::TestCase
  tests RemoteRepoSitesController

  def setup
    @user = User.find(1)
    request.session[:user_id] = @user.id
  end

  def test_index_success_without_data
    get :index
    assert_response :success
  end
end
