require File.expand_path('../../test_helper', __FILE__)

class FireHooksOnEveryBranchTest < ActionDispatch::IntegrationTest

  fixtures :projects,
    :users,
    :email_addresses,
    :roles,
    :members,
    :member_roles,
    :trackers,
    :projects_trackers,
    :enabled_modules,
    :issue_statuses,
    :issues,
    :enumerations,
    :custom_fields,
    :custom_values,
    :custom_fields_trackers

  class HookListener < Redmine::Hook::Listener

    attr_reader :hook_ids

    def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context)
      return unless context.has_key? :hook
      @hook_ids ||= []
      @hook_ids << context[:hook].id
    end

    def clear_hook_ids
      @hook_ids = []
    end

    def initialize(*args, &block)
      @hook_ids = []
      super
    end
  end

  def setup
    make_temp_dir
    @project = Project.find(3)
    Setting.enabled_scm << 'UndevGit'
    @repo = Repository::UndevGit.create!(project: @project, url: RD1, use_init_hooks: 1)
  end

  def teardown
    remove_temp_dir
  end

  def test_hook1
    hook1 = GlobalHook.create!(keywords: 'hook1', branches: '*', done_ratio: '10%')
    fetch_changesets_by_step
    assert_equal [hook1.id], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [], @hook_ids3
    assert_equal [], @hook_ids4
  end

  def test_hook2
    hook2_1 = GlobalHook.create!(keywords: 'hook2', branches: 'develop', done_ratio: '21%')
    hook2_2 = GlobalHook.create!(keywords: 'hook2', branches: 'staging', done_ratio: '22%')
    hook2_3 = GlobalHook.create!(keywords: 'hook2', branches: 'feature', done_ratio: '23%')
    hook2_4 = GlobalHook.create!(keywords: 'hook2', branches: 'master', done_ratio: '24%')
    fetch_changesets_by_step
    assert_equal [hook2_1.id, hook2_3.id, hook2_2.id], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [], @hook_ids3
    assert_equal [hook2_4.id], @hook_ids4
  end

  def test_hook3
    hook3_1 = GlobalHook.create!(keywords: 'hook3', branches: 'develop', done_ratio: '31%')
    hook3_2 = GlobalHook.create!(keywords: 'hook3', branches: 'master', done_ratio: '32%')
    fetch_changesets_by_step
    assert_equal [], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [hook3_1.id], @hook_ids3
    assert_equal [hook3_2.id], @hook_ids4
  end

  def test_hooks_priority_1
    hooks = create_global_hooks

    hook_feature = hooks.detect { |r| r.branches.include? 'feature' }.id
    hook_staging = hooks.detect { |r| r.branches.include? 'staging' }.id
    hook_develop = hooks.detect { |r| r.branches.include? 'develop' }.id
    hook_any     = hooks.detect { |r| r.branches.include? '*' }.id

    fetch_changesets_by_step

    assert_equal [hook_feature, hook_staging], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [hook_develop], @hook_ids3
    assert_equal [], @hook_ids4
  end

  def test_hooks_priority_2
    create_global_hooks
    hooks = create_project_hooks

    hook_feature = hooks.detect { |r| r.branches.include? 'feature' }.id
    hook_staging = hooks.detect { |r| r.branches.include? 'staging' }.id
    hook_develop = hooks.detect { |r| r.branches.include? 'develop' }.id
    hook_any     = hooks.detect { |r| r.branches.include? '*' }.id

    fetch_changesets_by_step

    assert_equal [hook_feature, hook_staging], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [hook_develop], @hook_ids3
    assert_equal [], @hook_ids4
  end

  def test_hooks_priority_3
    create_global_hooks
    create_project_hooks
    hooks = create_repo_hooks
    @repo.reload

    hook_feature = hooks.detect { |r| r.branches.include? 'feature' }.id
    hook_staging = hooks.detect { |r| r.branches.include? 'staging' }.id
    hook_develop = hooks.detect { |r| r.branches.include? 'develop' }.id
    hook_any     = hooks.detect { |r| r.branches.include? '*' }.id

    fetch_changesets_by_step

    assert_equal [hook_feature, hook_staging], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [hook_develop], @hook_ids3
    assert_equal [], @hook_ids4
  end

  def test_hooks_for_merged_commits
    hook_feature = GlobalHook.create!(
      keywords: 'hook6, hook7', branches: 'feature', done_ratio: '11%')
    hook_staging = GlobalHook.create!(
      keywords: 'hook6, hook7', branches: 'staging', done_ratio: '12%')

    @repo.reload

    fetch_changesets_by_step

    assert_equal [], @hook_ids1
    assert_equal [hook_feature.id, hook_staging.id], @hook_ids2
    assert_equal [], @hook_ids3
    assert_equal [], @hook_ids4
  end

  def create_global_hooks
    [
      GlobalHook.create!(
        keywords: 'hook3', branches: '*', done_ratio: '11%'),
      GlobalHook.create!(
        keywords: 'hook3', branches: 'feature', done_ratio: '12%'),
      GlobalHook.create!(
        keywords: 'hook3', branches: 'staging', done_ratio: '13%'),
      GlobalHook.create!(
        keywords: 'hook3', branches: 'develop', done_ratio: '14%')
    ]
  end

  def create_project_hooks
    [
      @project.hooks.create(
        keywords: 'hook3', branches: '*', done_ratio: '21%'),
      @project.hooks.create(
        keywords: 'hook3', branches: 'feature', done_ratio: '22%'),
      @project.hooks.create(
        keywords: 'hook3', branches: 'staging', done_ratio: '23%'),
      @project.hooks.create(
        keywords: 'hook3', branches: 'develop', done_ratio: '24%')
    ]
  end

  def create_repo_hooks
    [
      @project.hooks.create(
        keywords: 'hook3', branches: '*', done_ratio: '31%', repository: @repo),
      @project.hooks.create(
        keywords: 'hook3', branches: 'feature', done_ratio: '32%', repository: @repo),
      @project.hooks.create(
        keywords: 'hook3', branches: 'staging', done_ratio: '33%', repository: @repo),
      @project.hooks.create(
        keywords: 'hook3', branches: 'develop', done_ratio: '34%', repository: @repo)
    ]
  end

  def fetch_changesets_by_step
    listener = HookListener.instance
    listener.clear_hook_ids
    @repo.fetch_changesets
    @hook_ids1 = listener.hook_ids || []
    listener.clear_hook_ids
    @repo.send :remove_repository_folder
    @repo.url = RD2
    @repo.fetch_changesets
    @hook_ids2 = listener.hook_ids || []
    listener.clear_hook_ids
    @repo.send :remove_repository_folder
    @repo.url = RD3
    @repo.fetch_changesets
    @hook_ids3 = listener.hook_ids || []
    listener.clear_hook_ids
    @repo.send :remove_repository_folder
    @repo.url = RD4
    @repo.fetch_changesets
    @hook_ids4 = listener.hook_ids || []
  end
end
