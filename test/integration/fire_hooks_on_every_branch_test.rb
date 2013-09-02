require File.expand_path('../../test_helper', __FILE__)

# R4
#    *          c9 Merge branch 'develop'; hook9 #5
#    |\
# ----- -- ------------------------------------------------------------------------
# R3 |  |
#    |  *       c8 Merge branch 'feature' into develop; hook8 #5
#    |  |\
# ----- -- -- ----------------------------------------------------------------------
# R2 |  |  |  * c7 Merge branch 'feature' into staging; hook7 #5
#    |  |  | /|
#    |  |  || |
#    |  |  |/ |
#    |  |  *  | c6 hook6 #5
# ----- -- -- ----------------------------------------------------------------------
# R1 |  |  |  * c5 hook5 #5
#    |  |  |/
#    |  |  *    c4 hook4 #5
#    |  |  *    c3 hook3 #5
#    |  |/
#    |  *       c2 hook2 #5
#    |/
#    *          c1 hook1 #5
#
#    m  d  f  s
#    a  e  e  t
#    s  v  a  a
#    t  e  t  g
#    e  l  u  i
#    r  o  r  n
#       p  e  g
#
#  Hooks:
#    keywords       branches      new %     hook fired on
#    hook1          *             10        R1
#
#    hook2_1        develop       21        R1
#    hook2_2        feature       22        R1
#    hook2_3        staging       23        R1
#    hook2_4        master        24        R4
#
#    hook3_1        develop       31        R3
#    hook3_2        master        32        R4

class FireHooksOnEveryBranchTest < ActionDispatch::IntegrationTest
  RD1 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r1.git')
  RD2 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r2.git')
  RD3 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r3.git')
  RD4 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r4.git')

  CMT1 = '1a81e3a76c1fd2a5eef3c63d7b9ff36bf836548c'
  CMT2 = '725bc91aabb76019be9d0d8714e9aef15bd9753c'
  CMT3 = 'a578eac0e2f36e609fe49a5eec2f4386ab71cf24'
  CMT4 = '57096e16ce4541e2f02c330ffe24551f91f90cae'
  CMT5 = '0b652ac1bc8b9424230701dcc28511cd47df1c32'
  CMT6 = 'c18df3f4dca6fa808f19a3a60047274dddc7280c'
  CMT7 = '0d8c70c242b62e1e35fdbf2c5a35be3f1700fd40'
  CMT8 = '90045e487f0d5d966c446882965e543bcbbd353e'
  CMT9 = 'c25b5dd0f99b3cb2d102c9893de24b8c16797f0c'

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
    @repo = Repository::UndevGit.create!(:project => @project, :url => RD1, :use_init_hooks => 1)
  end

  def teardown
    remove_temp_dir
  end

  def test_hook1
    hook1 = GlobalHook.create!(:keywords => 'hook1', :branches => '*', :new_done_ratio => '10%')
    fetch_changesets_by_step
    assert_equal [hook1.id], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [], @hook_ids3
    assert_equal [], @hook_ids4
  end

  def test_hook2
    hook2_1 = GlobalHook.create!(:keywords => 'hook2', :branches => 'develop', :new_done_ratio => '21%')
    hook2_2 = GlobalHook.create!(:keywords => 'hook2', :branches => 'staging', :new_done_ratio => '22%')
    hook2_3 = GlobalHook.create!(:keywords => 'hook2', :branches => 'feature', :new_done_ratio => '23%')
    hook2_4 = GlobalHook.create!(:keywords => 'hook2', :branches => 'master',  :new_done_ratio => '24%')
    fetch_changesets_by_step
    assert_equal [hook2_1.id, hook2_3.id, hook2_2.id], @hook_ids1
    assert_equal [], @hook_ids2
    assert_equal [], @hook_ids3
    assert_equal [hook2_4.id], @hook_ids4
  end

  def test_hook3
    hook3_1 = GlobalHook.create!(:keywords => 'hook3', :branches => 'develop', :new_done_ratio => '31%')
    hook3_2 = GlobalHook.create!(:keywords => 'hook3', :branches => 'master',  :new_done_ratio => '32%')
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

    fetch_changesets_by_step

    assert_equal [hook_feature, hook_staging], @hook_ids1
    assert_equal [],                           @hook_ids2
    assert_equal [hook_develop],               @hook_ids3
    assert_equal [],                           @hook_ids4
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
    assert_equal [],                           @hook_ids2
    assert_equal [hook_develop],               @hook_ids3
    assert_equal [],                           @hook_ids4
  end

  def test_hooks_for_merged_commits
    hook_feature = GlobalHook.create!(
        :keywords => 'hook6, hook7', :branches => 'feature', :new_done_ratio => '11%')
    hook_staging = GlobalHook.create!(
        :keywords => 'hook6, hook7', :branches => 'staging', :new_done_ratio => '12%')

    @repo.reload

    fetch_changesets_by_step

    assert_equal [],                                 @hook_ids1
    assert_equal [hook_feature.id, hook_staging.id], @hook_ids2
    assert_equal [],                                 @hook_ids3
    assert_equal [],                                 @hook_ids4
 end

  def create_global_hooks
    [
      GlobalHook.create!(
        :keywords => 'hook3', :branches => '*', :new_done_ratio => '11%'),
      GlobalHook.create!(
        :keywords => 'hook3', :branches => 'feature', :new_done_ratio => '12%'),
      GlobalHook.create!(
        :keywords => 'hook3', :branches => 'staging', :new_done_ratio => '13%'),
      GlobalHook.create!(
        :keywords => 'hook3', :branches => 'develop', :new_done_ratio => '14%')
    ]
  end

  def create_project_hooks
    [
      @project.hooks.create(
        :keywords => 'hook3', :branches => '*', :new_done_ratio => '21%'),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'feature', :new_done_ratio => '22%'),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'staging', :new_done_ratio => '23%'),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'develop', :new_done_ratio => '24%')
    ]
  end

  def create_repo_hooks
    [
      @project.hooks.create(
        :keywords => 'hook3', :branches => '*', :new_done_ratio => '31%', :repository => @repo),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'feature', :new_done_ratio => '32%', :repository => @repo),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'staging', :new_done_ratio => '33%', :repository => @repo),
      @project.hooks.create(
        :keywords => 'hook3', :branches => 'develop', :new_done_ratio => '34%', :repository => @repo)
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
