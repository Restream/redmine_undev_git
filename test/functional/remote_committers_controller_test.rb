require File.expand_path('../../test_helper', __FILE__)

class RemoteCommittersControllerTest < ActionController::TestCase
  tests RemoteCommittersController

  def setup
    @user = create(:admin_user)
    request.session[:user_id] = @user.id
  end

  def test_committers_show_mapping_committers
    repo = create(:remote_repo)
    rev = create(:full_repo_revision, repo: repo)
    mapping = create(:remote_repo_site_user, site: repo.site, email: rev.committer_email)
    get :index, remote_repo_site_id: repo.site.id
    assert_response :success
    assert_match rev.committer_email, response.body
    assert_match mapping.user.name, response.body
  end
end
