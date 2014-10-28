require File.expand_path('../../../../test_helper', __FILE__)

class RedmineUndevGit::Services::RemoteRepoFetchTest < ActiveSupport::TestCase

  def setup
    make_temp_dir
    site = RemoteRepoSite::Gitlab.create!(:server_name => 'gitlab.com')
    remote_repo = site.repos.create!(:url => REPOSITORY_PATH)
    @service = RedmineUndevGit::Services::RemoteRepoFetch.new(remote_repo)
  end

  def teardown
    make_temp_dir
  end

  def test_service_creation_should_fail_with_remote_repo_not_persisted
    remote_repo = RemoteRepo.new
    assert_raise do
      RedmineUndevGit::Services::RemoteRepoFetch.new(remote_repo)
    end
  end

  def test_local_path_contain_repo_id_in_remote_repos_folder
    ending = File.join('REMOTE_REPOS', @service.repo.id.to_s)
    assert_match /#{ending}\z/, @service.local_path
  end

  def test_updating_root_url_on_scm_initialize
    assert @service.repo.root_url.blank?
    assert @service.scm
    assert_equal @service.local_path, @service.repo.root_url
  end

  def test_initialize_repo_should_clone_repo
    refute Dir.exists?(@service.local_path)
    @service.send :initialize_repository
    assert Dir.exists?(@service.local_path)
    assert @service.scm.cloned?
  end

  def test_get_head_revisions
    @service.initialize_repository
    revs = @service.head_revisions
    revs.map! { |rev| rev[0..6] }
    assert_equal %w{1ca7f5e 2a68215 67e7792 83ca5fd fba357b}, revs
  end

  def test_get_tail_revisions
    assert_equal [], @service.repo.tail_revisions
    @service.fetch
    revs = @service.repo.tail_revisions
    revs.map! { |rev| rev[0..6] }
    assert_equal %w{1ca7f5e 2a68215 67e7792 83ca5fd fba357b}, revs
  end

end
