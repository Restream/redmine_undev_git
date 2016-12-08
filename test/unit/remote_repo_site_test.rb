require File.expand_path('../../test_helper', __FILE__)

class RemoteRepoSiteTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses

  def setup
    @site = RemoteRepoSite::Gitlab.create(server_name: 'https://gitlab.com')
    assert @site
  end

  def test_find_user_by_redmine_email
    redmine_user = User.find(1)
    user         = @site.find_user_by_email(redmine_user.mail)
    assert_equal redmine_user, user
  end

  def test_find_user_by_site_email_with_mapping
    redmine_user = User.find(1)
    site_email   = 'othermail@site.com'
    @site.user_mappings.create(email: site_email, user: redmine_user)
    user = @site.find_user_by_email(redmine_user.mail)
    assert_equal redmine_user, user
  end

  def test_find_user_by_email_returns_anonymous
    redmine_user = User.find(1)
    user         = @site.find_user_by_email(redmine_user.mail)
    assert_equal redmine_user, user
  end

  def test_all_committers_with_mappings_returns_unique_mappings
    repo            = create(:remote_repo, site: @site)
    committer_email = 'committer@example.org'
    create_list(:remote_repo_revision, 5, repo: repo, committer_email: committer_email)

    mappings = @site.all_committers_with_mappings

    assert_equal [[committer_email, nil]], mappings
  end

  def test_all_committers_with_mappings_returns_email_with_mapped_user_id
    repo            = create(:remote_repo, site: @site)
    committer_email = 'committer@example.org'
    create_list(:remote_repo_revision, 5, repo: repo, committer_email: committer_email)
    user = User.find(1)
    @site.user_mappings.create(email: committer_email, user: user)

    mappings = @site.all_committers_with_mappings

    assert_equal [[committer_email, user.id]], mappings
  end
end
