require File.expand_path('../../../test_helper', __FILE__)

class RedmineUndevGit::ProjectsControllerTest < ActionController::TestCase
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

  tests ProjectsController

  def setup
    @user = User.find(2)
    @issue = Issue.find(1)
    @project = @issue.project
    User.current = @user
    request.session[:user_id] = 2
    make_temp_dir
  end

  def teardown
    remove_temp_dir
  end

  def test_repositories_settings_tab_will_show_remote_repos
    GlobalHook.create!(
        :branches   => '*',
        :keywords   => 'fixes',
        :status_id  => 3,
        :done_ratio => '100%'
    )
    repo = create_stubbed_remote_repo
    get :settings, :id => @project.id, :tab => 'repositories'
    assert_response :success
    assert_match repo.uri, response.body
  end

  def create_stubbed_remote_repo
    site         = RemoteRepoSite::Gitlab.create!(:server_name => 'gitlab.com')
    remote_repo = site.repos.create!(:url => RD1)
    revisions = [
        fake_revision(:message => "refs ##{@issue.id} fixes ##{@issue.id}")
    ]
    stubs_scm_revisions(revisions)
    remote_repo.fetch
    remote_repo
  end
end
