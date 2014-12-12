require File.expand_path('../../../test_helper', __FILE__)
require 'issues_controller'

class RedmineUndevGit::IssuesControllerTest < ActionController::TestCase
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
           :enumerations

  include Redmine::I18n

  def setup
    @controller = IssuesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @user = User.find(2)
    @issue = Issue.find(1)
    @project = @issue.project
    User.current = @user
    @request.session[:user_id] = 2
    make_temp_dir
  end

  def teardown
    remove_temp_dir
  end

  def test_show_branches_in_associated_revisions
    @repository = create_test_repository(project: @project)
    @repository.fetch_changesets
    changeset = @repository.changesets.last
    branches = Array.new(15) { |i| "fakebranch#{i}" }
    changeset.update_attribute :branches, branches
    @issue.changesets << changeset
    max_branches = RedmineUndevGit.max_branches_in_assoc

    get :show, id: 1
    assert_response :success

    assert_select 'div#issue-changesets a', { text: /fakebranch/ } do |links|
      assert_equal max_branches, links.length
    end
  end

  def test_show_repo_name_in_associated_revisions
    @repository = create_test_repository(project: @project)
    @repository.fetch_changesets
    changeset = @repository.changesets.last
    branches = %w[fakebranch]
    changeset.update_attribute :branches, branches
    @issue.changesets << changeset

    get :show, id: 1
    assert_response :success

    assert_select 'div#issue-changesets a', { text: /#{@repository.name}/ } do |links|
      assert_equal 1, links.length
      assert_match "/projects/ecookbook/repository/#{@repository.identifier_param}",
                   links[0].attributes['href']
    end
  end

  def test_show_remote_revisions_block
    Setting.commit_ref_keywords = 'hook4'

    user = User.find(1)
    site = RemoteRepoSite::Gitlab.create!(server_name: 'gitlab.com')
    site.stubs(:find_user_by_email).returns(user)
    repo = site.repos.create!(url: RD4)
    repo.fetch

    revision = repo.find_revision('57096e1')
    assert revision

    get :show, id: 5
    assert_response :success

    assert_select 'div#issue-changesets a', { text: /#{revision.short_sha}/ }
  end

  def test_user_with_permission_can_unlink_revision
    user = User.find(3)
    Role.find(2).add_permission!(:manage_related_issues)
    request.session[:user_id] = user.id
    issue = Issue.find(1)
    assert user.allowed_to?(:manage_related_issues, issue.project)

    rev = create(:full_repo_revision)
    rev.related_issues << issue

    put :remove_remote_revision, id: issue.id, remote_repo_id: rev.repo.id, sha: rev.sha

    assert_response :redirect
    refute rev.related_issues.include?(issue)
  end

  def test_user_without_permission_cant_unlink_revision
    user = User.find(9)
    request.session[:user_id] = user.id
    issue = Issue.find(1)
    refute user.allowed_to?(:manage_related_issues, issue.project)

    rev = create(:full_repo_revision)
    rev.related_issues << issue

    put :remove_remote_revision, id: issue.id, sha: rev.sha

    assert_response 403
    assert rev.related_issues.include?(issue)
  end
end
