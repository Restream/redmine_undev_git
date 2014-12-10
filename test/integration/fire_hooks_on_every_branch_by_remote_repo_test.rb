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

  def test_hook_applied_for_any_branch_one_time
    hook1 = GlobalHook.create!(keywords: 'hook1', branches: '*', done_ratio: '10%')

    fetch_step_by_step

    issue = Issue.find(5)
    assert_equal 10, issue.done_ratio

    assert @applied1.any?
    assert @applied2.empty?
    assert @applied3.empty?
    assert @applied4.empty?
  end

  def test_apply_only_one_hook_with_first_position
    hook2_1 = GlobalHook.create!(keywords: 'hook2', branches: 'develop', done_ratio: '21%')
    hook2_2 = GlobalHook.create!(keywords: 'hook2', branches: 'develop', done_ratio: '22%')
    hook2_3 = GlobalHook.create!(keywords: 'hook2', branches: 'develop', done_ratio: '23%')
    hook2_4 = GlobalHook.create!(keywords: 'hook2', branches: 'develop',  done_ratio: '24%')
    fetch_step_by_step

    issue = Issue.find(5)
    assert_equal 21, issue.done_ratio
    assert_equal 1, @applied1.length
    assert_equal hook2_1, @applied1.first.hook
    assert @applied2.empty?
    assert @applied3.empty?
    assert @applied4.empty?
  end

  def test_hook_applied_for_every_branch_by_one_hook
    hook2_1 = GlobalHook.create!(keywords: 'hook3', branches: 'feature,develop,staging,master', done_ratio: '21%')
    hook2_2 = GlobalHook.create!(keywords: 'hook3', branches: 'staging', done_ratio: '22%')
    hook2_3 = GlobalHook.create!(keywords: 'hook3', branches: 'feature', done_ratio: '23%')
    hook2_4 = GlobalHook.create!(keywords: 'hook3', branches: 'master',  done_ratio: '24%')
    fetch_step_by_step

    issue = Issue.find(5)
    assert_equal 21, issue.done_ratio

    assert_equal %w{feature staging}, branches(@applied1)
    assert @applied2.empty?
    assert_equal %w{develop}, branches(@applied3)
    assert_equal %w{master}, branches(@applied4)
  end

  def test_hook_applied_for_branch_by_two_hooks
    hook3_1 = GlobalHook.create!(keywords: 'hook3', branches: 'develop', done_ratio: '31%')
    hook3_2 = GlobalHook.create!(keywords: 'hook4', branches: 'master',  done_ratio: '32%')
    fetch_step_by_step

    issue = Issue.find(5)
    assert_equal 32, issue.done_ratio

    assert @applied1.empty?
    assert @applied2.empty?
    assert_equal %w{develop}, branches(@applied3)
    assert_equal %w{master}, branches(@applied4)
  end

  def test_hooks_with_branches_has_higher_priority
    GlobalHook.create!(keywords: 'hook3', branches: '*', done_ratio: '11%')
    GlobalHook.create!(keywords: 'hook3', branches: 'feature', done_ratio: '12%')

    fetch_step_by_step

    issue = Issue.find(5)
    assert_equal 12, issue.done_ratio
  end

  def test_project_hooks_has_higher_priority
    GlobalHook.create!(keywords: 'hook3', branches: '*', done_ratio: '11%')
    GlobalHook.create!(keywords: 'hook3', branches: 'feature', done_ratio: '12%')
    @project.hooks.create(keywords: 'hook3', branches: '*', done_ratio: '21%')

    fetch_step_by_step

    issue = Issue.find(5)
    assert_equal 21, issue.done_ratio
  end

  def test_hooks_applied_in_reverse_date_order_on_same_branch
    GlobalHook.create!(keywords: 'hook1', branches: 'master', done_ratio: '11%')
    GlobalHook.create!(keywords: 'hook2', branches: 'master', done_ratio: '12%')
    GlobalHook.create!(keywords: 'hook3', branches: 'master', done_ratio: '13%')
    GlobalHook.create!(keywords: 'hook4', branches: 'master', done_ratio: '14%')
    GlobalHook.create!(keywords: 'hook6', branches: 'master', done_ratio: '16%')

    site = RemoteRepoSite::Gitlab.create!(server_name: 'gitlab.com')
    repo = site.repos.create!(url: RD4)
    repo.fetch

    applied_keywords = RemoteRepoHook.order(:id).all.map { |ah| ah.hook.keywords.join }

    assert_equal %w{hook1 hook2 hook3 hook4 hook6}, applied_keywords
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

  # def test_fetch_redmine_as_a_big_repo
  #   skip
  #   site = RemoteRepoSite:Gitlab.create!(:server_name: 'gitlab.com')
  #   repo = site.repos.create!(url: Rails.root)
  #   assert_nothing_raised do
  #     repo.fetch
  #   end
  # end

  def fetch_step_by_step
    site    = RemoteRepoSite::Gitlab.create!(server_name: 'gitlab.com')
    @repo   = site.repos.create!(url: RD1)
    last_id = get_last_id_of_applied_hooks

    @repo.fetch
    @applied1 = RemoteRepoHook.where('id > ?', last_id).all
    last_id   = get_last_id_of_applied_hooks

    @repo.url = RD2
    @repo.fetch
    @applied2 = RemoteRepoHook.where('id > ?', last_id).all
    last_id   = get_last_id_of_applied_hooks

    @repo.url = RD3
    @repo.fetch
    @applied3 = RemoteRepoHook.where('id > ?', last_id).all
    last_id   = get_last_id_of_applied_hooks

    @repo.url = RD4
    @repo.fetch
    @applied4 = RemoteRepoHook.where('id > ?', last_id).all
  end

  def branches(applied_hooks)
    applied_hooks.map { |h| h.ref.try(:name) || '*' }.sort
  end

  def get_last_id_of_applied_hooks
    RemoteRepoHook.any? ? RemoteRepoHook.last.id : 0
  end
end
