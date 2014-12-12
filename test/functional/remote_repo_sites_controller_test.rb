require File.expand_path('../../test_helper', __FILE__)

class RemoteRepoSitesControllerTest < ActionController::TestCase
  tests RemoteRepoSitesController

  def setup
    @user = create(:admin_user)
    request.session[:user_id] = @user.id
  end

  def test_index_success_without_sites
    get :index
    assert_response :success
  end

  def test_index_shows_sites
    site1 = create(:site)
    site2 = create(:site)
    get :index
    assert_response :success
    assert_match site1.server_name, response.body
    assert_tag tag: 'a', attributes: { href: site1.uri }
    assert_match site2.server_name, response.body
    assert_tag tag: 'a', attributes: { href: site2.uri }
  end
end
