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

class ChangeIssueByHookTest < ActionDispatch::IntegrationTest
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

  def setup
    make_temp_dir
    @project = Project.find(3)
    Setting.enabled_scm << 'UndevGit'
    @repo = Repository::UndevGit.create!(:project => @project,
                                         :url => RD4,
                                         :use_init_hooks => 1)
    @issue = Issue.find(5)
  end

  def teardown
    remove_temp_dir
  end

  def test_issue_changed_by_hook
    hook = GlobalHook.create!(
        :keywords => 'hook9',
        :branches => '*',
        :status => IssueStatus.find(2),
        :done_ratio => '16%',
        :assigned_to => User.find(2),
        :custom_field_values => {
            1 => 'PostgreSQL'
        }
    )
    assert_not_equal hook.status, @issue.status
    assert_not_equal hook.done_ratio, @issue.done_ratio
    assert_not_equal hook.assigned_to, @issue.assigned_to

    hook_cfv = hook.custom_value_for(1)
    assert hook_cfv, 'hook custom_field_value must present'
    issue_cfv = @issue.custom_value_for(1)
    assert_nil issue_cfv, 'issue custom_field_value must be nil'

    @repo.fetch_changesets
    @issue.reload

    assert_equal hook.status, @issue.status
    assert_equal hook.done_ratio, @issue.done_ratio
    assert_equal hook.assigned_to, @issue.assigned_to

    hook_cfv = hook.custom_value_for(1)
    assert hook_cfv, 'hook custom_field_value must present'
    issue_cfv = @issue.custom_value_for(1)
    assert issue_cfv, 'issue custom_field_value must present'
    assert_equal hook_cfv.value, issue_cfv.value
  end

end
