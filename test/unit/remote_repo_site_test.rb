require File.expand_path('../../test_helper', __FILE__)

class RemoteRepoSiteTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @site = RemoteRepoSite::Gitlab.create(:server_name => 'https://gitlab.com')
    assert @site
  end

  def test_find_user_by_redmine_email
    redmine_user = User.find(1)
    user = @site.find_user_by_email(redmine_user.mail)
    assert_equal redmine_user, user
  end

  def test_find_user_by_site_email_with_mapping
    redmine_user = User.find(1)
    site_email = 'othermail@site.com'
    @site.user_mappings.create(:email => site_email, :user => redmine_user)
    user = @site.find_user_by_email(redmine_user.mail)
    assert_equal redmine_user, user
  end

  def test_find_user_by_email_returns_anonymous
    redmine_user = User.find(1)
    user = @site.find_user_by_email(redmine_user.mail)
    assert_equal redmine_user, user
  end
end
