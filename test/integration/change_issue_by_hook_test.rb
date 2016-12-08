require File.expand_path('../../test_helper', __FILE__)

class ChangeIssueByHookTest < ActionDispatch::IntegrationTest

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

  def setup
    make_temp_dir
    @project = Project.find(3)
    Setting.enabled_scm << 'UndevGit'
    @repo  = Repository::UndevGit.create!(
      project:        @project,
      url:            RD4,
      use_init_hooks: 1
    )
    @issue = Issue.find(5)
  end

  def teardown
    remove_temp_dir
  end

  def test_issue_changed_by_hook
    hook = GlobalHook.create!(
      keywords:            'hook9',
      branches:            '*',
      status:              IssueStatus.find(2),
      done_ratio:          '16%',
      assignee_type:       GlobalHook::USER,
      assigned_to:         User.find(2),
      custom_field_values: {
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

  def test_issue_changed_by_hook_to_author
    GlobalHook.create!(
      keywords:      'hook9',
      branches:      '*',
      assignee_type: GlobalHook::AUTHOR
    )
    assert_not_equal @issue.author, @issue.assigned_to

    @repo.fetch_changesets
    @issue.reload

    assert_equal @issue.author, @issue.assigned_to
  end

end
