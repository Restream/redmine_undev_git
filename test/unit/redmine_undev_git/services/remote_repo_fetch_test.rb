require File.expand_path('../../../../test_helper', __FILE__)

class RedmineUndevGit::Services::RemoteRepoFetchTest < ActiveSupport::TestCase
  fixtures :issues

  def setup
    make_temp_dir
    site = RemoteRepoSite::Gitlab.create!(:server_name => 'gitlab.com')
    remote_repo = site.repos.create!(:url => REPOSITORY_PATH)
    @service = RedmineUndevGit::Services::RemoteRepoFetch.new(remote_repo)
  end

  def teardown
    remove_temp_dir
  end

  def test_service_creation_should_fail_with_remote_repo_not_persisted
    remote_repo = RemoteRepo.new
    assert_raise RedmineUndevGit::Services::ServiceError do
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

  def test_revisions_from_start
    incl_revs = %w{9a6f3b9 67e7792 4a79347}
    excl_revs = []
    @service.initialize_repository
    revs = @service.revisions(incl_revs, excl_revs)
    assert revs
    assert_equal 6, revs.length
    revs_hashes = revs.map { |rev| rev.identifier[0..6] }.sort
    assert_equal %w{3621194 4a79347 67e7792 7234cb2 899a15d 9a6f3b9}, revs_hashes
  end

  def test_revisions_in_middle
    incl_revs = %w{4fc55c4 67e7792 61b685f}
    excl_revs = %w{9a6f3b9 67e7792 4a79347}
    @service.initialize_repository
    revs = @service.revisions(incl_revs, excl_revs)
    assert revs
    assert_equal 4, revs.length
    revs_hashes = revs.map { |rev| rev.identifier[0..6] }.sort
    assert_equal %w{2f9c009 4fc55c4 57ca437 61b685f}, revs_hashes
  end

  def test_fix_keywords_returns_all_keywords_from_hooks
    hooks = [stub(:keywords => ['a  ', 'b', ' c']), stub(:keywords => ['a', '  d'])]
    @service.stubs(:all_applicable_hooks).returns(hooks)
    fix_keywords = @service.fix_keywords
    assert fix_keywords
    assert_equal %w{a b c d}, fix_keywords.sort
  end

  def test_ref_keywords_returns_all_keywords_from_settings_except_asterisk
    Setting.stubs(:commit_ref_keywords).returns('a, b, c   ,*, d')
    ref_keywords = @service.ref_keywords
    assert ref_keywords
    assert_equal %w{a b c d}, ref_keywords.sort
  end

  def test_any_ref_keywords_returns_true_if_asterisk_present
    Setting.stubs(:commit_ref_keywords).returns('a, b, c   ,*, d')
    assert @service.any_ref_keyword?
  end

  def test_any_ref_keywords_returns_false_unless_asterisk
    Setting.stubs(:commit_ref_keywords).returns('a, b, c   ,d')
    refute @service.any_ref_keyword?
  end

  def test_parse_comments_should_returns_issue_ids_by_ref_keywords
    Setting.stubs(:commit_ref_keywords).returns('keyword1,keyword2,keyword3')
    parsed = @service.parse_comments('keyword1 #1, and keyword2 #2 but not keyword3')
    assert parsed
    assert_equal [1, 2], parsed[:ref_issues]
  end

  def test_parse_comments_should_returns_unique_issue_ids
    Setting.stubs(:commit_ref_keywords).returns('keyword1,keyword2,keyword3')
    parsed = @service.parse_comments('keyword1 #1, and keyword2 #2 and keyword3 #1')
    assert parsed
    assert_equal [1, 2], parsed[:ref_issues]
  end

  def test_parse_comments_should_returns_issue_ids_by_asterisk
    Setting.stubs(:commit_ref_keywords).returns('*')
    parsed = @service.parse_comments('keyword1 #1, and keyword2 #2 and #3')
    assert parsed
    assert_equal [1, 2, 3], parsed[:ref_issues]
  end

  def test_parse_comments_should_returns_issue_ids_for_change_by_keywords
    hooks = [
        stub(:keywords => ['keyword1']),
        stub(:keywords => ['keyword2']),
        stub(:keywords => ['keyword3'])
    ]
    @service.stubs(:all_applicable_hooks).returns(hooks)
    parsed = @service.parse_comments('keyword1 #1, and keyword2 #2 and keyword3 #1')
    assert parsed
    assert_equal [1, 2], parsed[:fix_issues].keys
    assert_equal ['keyword1', 'keyword3'], parsed[:fix_issues][1]
    assert_equal ['keyword2'], parsed[:fix_issues][2]
  end

  def test_link_revision_to_issues
    @service.initialize_repository
    revision = @service.repo.revisions.create!
    @service.link_revision_to_issues(revision, [1, 2, 100500])
    assert_equal [1, 2], revision.related_issue_ids
  end

end
