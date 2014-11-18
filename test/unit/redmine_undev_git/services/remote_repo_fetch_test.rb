require File.expand_path('../../../../test_helper', __FILE__)

class RedmineUndevGit::Services::RemoteRepoFetchTest < ActiveSupport::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :repositories

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
    assert @service.scm.repository_exists?
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
    revisions = @service.scm.revisions
    revision = revisions.first
    @service.link_revision_to_issues(revision, [1, 2, 100500])
    repo_revision = @service.repo.revisions.find_by_sha(revision.sha)
    assert_equal [1, 2], repo_revision.related_issue_ids
  end

  def test_get_cached_repo_revision
    @service.initialize_repository
    revisions = @service.scm.revisions
    revision_x = revisions.first
    revision_y = revisions.last
    assert revisions
    repo_revision_x1 = @service.repo_revision_by_git_revision(revision_x)
    assert repo_revision_x1
    assert repo_revision_x1.persisted?
    repo_revision_y = @service.repo_revision_by_git_revision(revision_y)
    assert repo_revision_y
    assert repo_revision_y.persisted?
    refute_equal repo_revision_y, repo_revision_x1
    repo_revision_x2 = @service.repo_revision_by_git_revision(revision_x)
    assert_equal repo_revision_x1, repo_revision_x2
  end

  def test_apply_hooks_by_admin
    # this hook should apply
    hook1 = ProjectHook.create!(
        :project_id => 1,
        :branches => 'master',
        :keywords => 'fix',
        :status_id => 3,
        :done_ratio => '50%'
    )
    # this hook should not apply
    ProjectHook.create!(
        :project_id => 1,
        :branches => '*',
        :keywords => 'fix',
        :status_id => 1,
        :done_ratio => '20%'
    )

    issue = Issue.find(1)
    user = User.find(1)

    @service.initialize_repository

    revision = RedmineUndevGit::Services::GitRevision.new()
    revision.sha = 'deff712f05a90d96edbd70facc47d944be5897e3'
    revision.aname = user.name
    revision.aemail = user.mail
    revision.adate = Time.parse('2009-06-26 23:06:56 -0700')
    revision.cname = revision.aname
    revision.cemail = revision.aemail
    revision.cdate = revision.adate
    revision.message = "this commit should fix ##{issue.id} by 50%"

    @service.apply_hooks(revision, ['fix'], issue)

    issue.reload

    assert_equal 50, issue.done_ratio
    assert_equal 3, issue.status_id

    repo_revision = @service.repo.revisions.find_by_sha(revision.sha)

    assert repo_revision
    assert_equal [hook1], repo_revision.applied_hooks.map { |ah| ah.hook }
  end

  def test_not_apply_hooks_by_unknown_user
    ProjectHook.create!(
        :project_id => 1,
        :branches => 'master',
        :keywords => 'fix',
        :status_id => 3,
        :done_ratio => '50%'
    )

    issue = Issue.find(1)

    @service.initialize_repository

    revision = RedmineUndevGit::Services::GitRevision.new()
    revision.sha = 'deff712f05a90d96edbd70facc47d944be5897e3'
    revision.aname = 'Simon Peterson'
    revision.aemail = 'simon@example.com'
    revision.adate = Time.parse('2009-06-26 23:06:56 -0700')
    revision.cname = revision.aname
    revision.cemail = revision.aemail
    revision.cdate = revision.adate
    revision.message = "this commit should not fix ##{issue.id} by 50%"

    @service.apply_hooks(revision, ['fix'], issue)

    issue.reload

    assert_equal 0, issue.done_ratio  # doesn't changed
    assert_equal 1, issue.status_id   # doesn't changed

    repo_revision = @service.repo.revisions.find_by_sha(revision.sha)

    assert repo_revision
    assert repo_revision.applied_hooks.empty?
  end

end
