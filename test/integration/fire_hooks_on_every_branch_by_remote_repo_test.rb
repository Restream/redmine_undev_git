require File.expand_path('../../test_helper', __FILE__)

class FireHooksOnEveryBranchByRemoteRepoTest < ActionDispatch::IntegrationTest

  fixtures :projects,
           :users,
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

  def setup
    make_temp_dir
    @project = Project.find(3)
    Policies::ApplyHooks.stubs(:allowed?).returns(true)
  end

  def teardown
    remove_temp_dir
  end

  def test_hook1
    hook1 = GlobalHook.create!(:keywords => 'hook1', :branches => '*', :done_ratio => '10%')
    fetch_step_by_step
    assert_equal [hook1.id], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [], @hook_ids3
    assert_equal [], @hook_ids4
  end

  def test_hook2
    hook2_1 = GlobalHook.create!(:keywords => 'hook2', :branches => 'develop', :done_ratio => '21%')
    hook2_2 = GlobalHook.create!(:keywords => 'hook2', :branches => 'staging', :done_ratio => '22%')
    hook2_3 = GlobalHook.create!(:keywords => 'hook2', :branches => 'feature', :done_ratio => '23%')
    hook2_4 = GlobalHook.create!(:keywords => 'hook2', :branches => 'master',  :done_ratio => '24%')
    fetch_step_by_step
    assert_equal [hook2_1.id, hook2_3.id, hook2_2.id], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [], @hook_ids3
    assert_equal [hook2_4.id], @hook_ids4
  end

  def test_hook3
    hook3_1 = GlobalHook.create!(:keywords => 'hook3', :branches => 'develop', :done_ratio => '31%')
    hook3_2 = GlobalHook.create!(:keywords => 'hook3', :branches => 'master',  :done_ratio => '32%')
    fetch_step_by_step
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

    fetch_step_by_step

    assert_equal [hook_feature, hook_staging], @hook_ids1
    assert_equal [],                           @hook_ids2
    assert_equal [hook_develop],               @hook_ids3
    assert_equal [],                           @hook_ids4
  end

  def test_hooks_priority_2
    create_global_hooks
    hooks = create_project_hooks

    hook_feature = hooks.detect { |r| r.branches.include? 'feature' }.id
    hook_staging = hooks.detect { |r| r.branches.include? 'staging' }.id
    hook_develop = hooks.detect { |r| r.branches.include? 'develop' }.id
    hook_any     = hooks.detect { |r| r.branches.include? '*' }.id

    fetch_step_by_step

    assert_equal [hook_feature, hook_staging], @hook_ids1
    assert_equal [],                           @hook_ids2
    assert_equal [hook_develop],               @hook_ids3
    assert_equal [],                           @hook_ids4
  end

  def test_hooks_for_merged_commits
    hook_feature = GlobalHook.create!(
        :keywords => 'hook6, hook7', :branches => 'feature', :done_ratio => '11%')
    hook_staging = GlobalHook.create!(
        :keywords => 'hook6, hook7', :branches => 'staging', :done_ratio => '12%')

    fetch_step_by_step

    assert_equal [],                                 @hook_ids1
    assert_equal [hook_feature.id, hook_staging.id], @hook_ids2
    assert_equal [],                                 @hook_ids3
    assert_equal [],                                 @hook_ids4
 end

  def create_global_hooks
    [
      GlobalHook.create!(
        :keywords => 'hook3', :branches => '*', :done_ratio => '11%'),
      GlobalHook.create!(
        :keywords => 'hook3', :branches => 'feature', :done_ratio => '12%'),
      GlobalHook.create!(
        :keywords => 'hook3', :branches => 'staging', :done_ratio => '13%'),
      GlobalHook.create!(
        :keywords => 'hook3', :branches => 'develop', :done_ratio => '14%')
    ]
  end

  def create_project_hooks
    [
      @project.hooks.create(
        :keywords => 'hook3', :branches => '*', :done_ratio => '21%'),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'feature', :done_ratio => '22%'),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'staging', :done_ratio => '23%'),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'develop', :done_ratio => '24%')
    ]
  end

  def fetch_step_by_step
    site = RemoteRepoSite::Gitlab.create!(:server_name => 'gitlab.com')
    repo = site.repos.create!(:url => RD1)
    last_id = get_last_id_of_applied_hooks

    repo.fetch
    @hook_ids1 = RemoteRepoHook.where('id > ?', last_id).pluck(:hook_id).sort
    last_id = get_last_id_of_applied_hooks

    repo.url = RD2
    repo.fetch
    @hook_ids2 = RemoteRepoHook.where('id > ?', last_id).pluck(:hook_id).sort
    last_id = get_last_id_of_applied_hooks

    repo.url = RD3
    repo.fetch
    @hook_ids3 = RemoteRepoHook.where('id > ?', last_id).pluck(:hook_id).sort
    last_id = get_last_id_of_applied_hooks

    repo.url = RD4
    repo.fetch
    @hook_ids4 = RemoteRepoHook.where('id > ?', last_id).pluck(:hook_id).sort
  end

  def get_last_id_of_applied_hooks
    RemoteRepoHook.any? ? RemoteRepoHook.last.id : 0
  end
end
