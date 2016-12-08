require File.expand_path('../../../../test_helper', __FILE__)

class RedmineUndevGit::Services::RemoteRepoFetchTest < ActiveSupport::TestCase
  fixtures :projects,
    :users,
    :email_addresses,
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
    @site       = RemoteRepoSite::Gitlab.create!(server_name: 'gitlab.com')
    remote_repo = @site.repos.create!(url: RD4)
    @service    = RedmineUndevGit::Services::RemoteRepoFetch.new(remote_repo)
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
    assert_equal %w{0d8c70c 90045e4 c18df3f c25b5dd}, revs
  end

  def test_tail_revisions_stored_after_fetch
    assert_equal [], @service.repo.tail_revisions
    @service.fetch
    repo = @service.repo
    repo.reload
    revs = repo.tail_revisions
    revs.map! { |rev| rev[0..6] }
    assert_equal %w{0d8c70c 90045e4 c18df3f c25b5dd}, revs
  end

  def test_fix_keywords_returns_all_keywords_from_hooks
    hooks = [stub(keywords: ['a  ', 'b', ' c']), stub(keywords: ['a', '  d'])]
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

  def test_link_revision_to_issues
    @service.initialize_repository
    revisions = @service.scm.revisions
    revision  = revisions.first
    Policies::ReferenceToIssue.stubs(:allowed?).returns(true)
    [1, 2, 100500].each { |id| @service.link_revision_to_issue(revision, id) }
    repo_revision = @service.repo.revisions.find_by_sha(revision.sha)
    assert_equal [1, 2], repo_revision.related_issue_ids
  end

  def test_get_cached_repo_revision
    @service.initialize_repository
    revisions  = @service.scm.revisions
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

  def test_create_refs_when_create_repo_revision
    @service.initialize_repository
    revisions    = @service.scm.revisions
    revision     = revisions.first
    exp_branches = @service.scm.branches(revision.sha).map(&:name)

    repo_revision = @service.repo_revision_by_git_revision(revision)
    branches      = repo_revision.refs.map(&:name)

    assert_equal exp_branches.sort, branches.sort
  end

  def test_head_branches_returns_branches_name
    @service.initialize_repository
    branches = @service.head_branches.sort
    assert_equal %w{develop feature master staging}, branches
  end

  def test_update_repo_refs
    @service.initialize_repository
    @service.update_repo_refs
    branches = @service.head_branches.sort
    refs     = @service.repo.refs.pluck(:name).sort
    assert_equal branches, refs
  end

  def test_apply_hooks_by_admin
    # this hook should apply
    hook1 = ProjectHook.create!(
      project_id: 3,
      branches:   'master',
      keywords:   'hook9',
      status_id:  3,
      done_ratio: '50%'
    )
    # this hook should not apply
    ProjectHook.create!(
      project_id: 3,
      branches:   '*',
      keywords:   'hook9',
      status_id:  1,
      done_ratio: '20%'
    )

    user = User.find(1) # admin
    @service.stubs(:user_by_email).returns(user)

    @service.initialize_repository
    @service.apply_hooks_to_issues

    repo_revision = @service.repo.revisions.find_by_sha(CMT9)
    assert repo_revision

    assert_equal 1, repo_revision.applied_hooks.count
    applied_hook = repo_revision.applied_hooks.first

    assert_equal hook1, applied_hook.hook
    assert_equal 'master', applied_hook.ref.name

    issue = Issue.find(5)

    assert_equal 50, issue.done_ratio
    assert_equal 3, issue.status_id
  end

  def test_not_apply_hooks_by_unknown_user_if_deny
    ProjectHook.create!(
      project_id: 3,
      branches:   'master',
      keywords:   'hook3',
      status_id:  3,
      done_ratio: '50%'
    )


    @service.initialize_repository
    @service.apply_hooks_to_issues

    Policies::ApplyHooks.stubs(:allowed?).returns(false)

    issue = Issue.find(5)

    issue.reload

    assert_equal 0, issue.done_ratio # doesn't changed
    assert_equal 1, issue.status_id # doesn't changed

    repo_revision = @service.repo.revisions.find_by_sha(CMT3)

    assert repo_revision.applied_hooks.empty?
  end

  def test_apply_hooks_by_unknown_user_if_allowed
    hook1 = ProjectHook.create!(
      project_id: 3,
      branches:   'master',
      keywords:   'hook3',
      status_id:  3,
      done_ratio: '50%'
    )

    Policies::ApplyHooks.stubs(:allowed?).returns(true)

    @service.initialize_repository
    @service.apply_hooks_to_issues

    issue = Issue.find(5)

    assert_equal 50, issue.done_ratio
    assert_equal 3, issue.status_id

    repo_revision = @service.repo.revisions.find_by_sha(CMT3)

    assert repo_revision
    assert_equal [hook1], repo_revision.applied_hooks.map { |ah| ah.hook }
  end

  def test_find_revisions_returns_revisions_with_sharp_sign_in_comments
    @service.initialize_repository

    revisions = @service.find_new_revisions
    revisions.map! { |rev| rev.sha[0..6] }
    assert_equal 9, revisions.length
    assert_equal %w{1a81e3a 725bc91 a578eac 57096e1 c18df3f 90045e4 0b652ac c25b5dd 0d8c70c}, revisions
  end

  def test_find_revisions_returns_only_new_revisions
    remote_repo = @site.repos.create!(url: RD1)
    service     = RedmineUndevGit::Services::RemoteRepoFetch.new(remote_repo)
    service.initialize_repository
    service.repo.tail_revisions = service.head_revisions
    service.repo.save!
    service.scm.fetch_url = RD2
    service.download_changes

    revisions = service.find_new_revisions

    revisions.map! { |rev| rev.sha[0..6] }
    assert_equal 2, revisions.length
    assert_equal %w{c18df3f 0d8c70c}, revisions
  end

  def test_refetch_dont_add_new_revisions
    Setting.commit_ref_keywords = '*'
    Policies::ReferenceToIssue.stubs(:allowed?).returns(true)
    @service.fetch
    revisions_count = @service.repo.revisions.count
    assert revisions_count > 0
    @service.refetch
    assert_equal revisions_count, @service.repo.revisions.count
  end

  def test_refetch_dont_add_new_timelogs
    Setting.commit_ref_keywords    = '*'
    Setting.commit_logtime_enabled = '1'
    revisions                      = [
      fake_revision(message: '#1 @2h'),
      fake_revision(message: '#5 @3h')
    ]
    stubs_scm_revisions(revisions)

    @service.fetch

    time_entries_count = @service.repo.time_entries.count
    assert_equal 2, time_entries_count
    @service.refetch
    assert_equal time_entries_count, @service.repo.time_entries.count
  end

  def test_refetch_dont_add_apply_new_hooks
    GlobalHook.create!(
      branches:   '*',
      keywords:   'half-fix',
      status_id:  3,
      done_ratio: '50%'
    )
    revisions = [
      fake_revision(message: 'half-fix #1'),
      fake_revision(message: 'half-fix #5')
    ]
    stubs_scm_revisions(revisions)

    @service.fetch

    hooks_count = @service.repo.applied_hooks.count
    assert_equal 2, hooks_count
    @service.refetch
    assert_equal hooks_count, @service.repo.applied_hooks.count
  end

  def test_hook_was_applied_finds_applied_hook_for_particular_branch
    repo         = @service.repo
    branch       = 'master'
    repo_ref     = create(:remote_repo_ref, repo: repo, name: branch)
    hook         = create(:project_hook)
    keyword      = hook.keywords.first
    rev          = create(:remote_repo_revision_full, repo: repo)
    applied_hook = create(:remote_repo_hook,
      revision:     rev,
      ref:          repo_ref,
      author_email: rev.author_email,
      author_date:  rev.author_date,
      keyword:      keyword,
      branch:       branch
    )

    req               = RedmineUndevGit::Services::RemoteRepoFetch::HookRequest.new
    req.issue         = applied_hook.issue
    req.hook          = hook
    req.repo_revision = applied_hook.revision
    req.keyword       = applied_hook.keyword
    req.branch        = applied_hook.branch

    assert @service.hook_was_applied?(req)

    other_repo     = create(:remote_repo)
    other_hook     = create(:project_hook)
    other_revision = create(:remote_repo_revision,
      repo:         other_repo,
      sha:          'OTHERSHA',
      author_email: rev.author_email,
      author_date:  rev.author_date
    )

    req               = RedmineUndevGit::Services::RemoteRepoFetch::HookRequest.new
    req.issue         = applied_hook.issue
    req.hook          = other_hook
    req.repo_revision = other_revision
    req.keyword       = applied_hook.keyword
    req.branch        = applied_hook.branch

    assert @service.hook_was_applied?(req)
  end

  def test_hook_was_applied_finds_applied_hook_for_any_branch
    repo         = @service.repo
    hook         = create(:project_hook, branches: '*')
    keyword      = hook.keywords.first
    rev          = create(:remote_repo_revision_full, repo: repo)
    applied_hook = create(:remote_repo_hook,
      revision:     rev,
      ref:          nil,
      author_email: rev.author_email,
      author_date:  rev.author_date,
      keyword:      keyword,
      branch:       nil
    )

    req               = RedmineUndevGit::Services::RemoteRepoFetch::HookRequest.new
    req.issue         = applied_hook.issue
    req.hook          = hook
    req.repo_revision = applied_hook.revision
    req.keyword       = applied_hook.keyword
    req.branch        = nil

    assert @service.hook_was_applied?(req)

    other_repo     = create(:remote_repo)
    other_hook     = create(:project_hook, branches: '*')
    other_revision = create(:remote_repo_revision,
      repo:         other_repo,
      sha:          'OTHERSHA',
      author_email: rev.author_email,
      author_date:  rev.author_date
    )

    req               = RedmineUndevGit::Services::RemoteRepoFetch::HookRequest.new
    req.issue         = applied_hook.issue
    req.hook          = other_hook
    req.repo_revision = other_revision
    req.keyword       = applied_hook.keyword
    req.branch        = nil

    assert @service.hook_was_applied?(req)
  end

  def test_create_remote_repo_revision_stores_committer_email_and_name
    revision        = RedmineUndevGit::Services::GitRevision.new
    revision.sha    = '111'
    revision.aname  = 'aname'
    revision.aemail = 'aemail'
    revision.cname  = 'cname'
    revision.cemail = 'cemail'
    @service.stubs(:update_remote_repo_revision_refs).returns(nil)
    repo_revision = @service.create_remote_repo_revision(revision)
    assert_equal 'aname', repo_revision.author_name
    assert_equal 'aemail', repo_revision.author_email
    assert_equal 'cname', repo_revision.committer_name
    assert_equal 'cemail', repo_revision.committer_email
  end

  def test_apply_hooks_by_hook_from_issue_project
    hook1 = ProjectHook.create!(
      project_id: 1,
      branches:   'master',
      keywords:   'hook3',
      status_id:  3,
      done_ratio: '30%'
    )
    hook2 = ProjectHook.create!(
      project_id: 3,
      branches:   'master',
      keywords:   'hook3',
      status_id:  3,
      done_ratio: '50%'
    )

    Policies::ApplyHooks.stubs(:allowed?).returns(true)

    @service.initialize_repository
    @service.apply_hooks_to_issues

    issue = Issue.find(5) # project_id: 3

    assert_equal 50, issue.done_ratio
    assert_equal 3, issue.status_id

    repo_revision = @service.repo.revisions.find_by_sha(CMT3)

    assert repo_revision
    assert_equal [hook2], repo_revision.applied_hooks.map { |ah| ah.hook }
  end

  def shorted(revisions)
    revisions.map { |rev| rev.sha[0..6] }.sort
  end
end
