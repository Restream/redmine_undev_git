require File.expand_path('../../test_helper', __FILE__)

class ReceiveExternalHooksTest < ActionDispatch::IntegrationTest
  fixtures :projects, :users, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  PRJ_ID     = 3

  def setup
    make_temp_dir
    Setting.enabled_scm << 'UndevGit'
    User.current = nil
    @project    = Project.find(PRJ_ID)
    RedmineUndevGit.fetch_by_web_hook = '1'
  end

  def test_fetch_after_gitlab_push_hook
    repository = create_test_repository(:project => @project, :url => 'https://example.com/diaspora.git')
    assert repository
    Workers::RepositoryFetcher.expects(:defer).with(repository.id).at_least_once
    post '/gitlab_hooks', gitlab_payload.to_json, gitlab_headers
    assert_response :success
  end

  def gitlab_payload
    {
        before: '95790bf891e76fee5e1747ab589903a6a1f80f22',
        after: 'da1560886d4f094c3e6c9ef40349f7d38b5d27d7',
        ref: 'refs/heads/master',
        user_id: 4,
        user_name: 'John Smith',
        project_id: 15,
        repository: {
            name: 'Diaspora',
            url: 'git@example.com:diaspora.git',
            description: '',
            homepage: 'http://example.com/diaspora'
        },
        commits: [
            {
                id: 'b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327',
                message: 'Update Catalan translation to e38cb41.',
                timestamp: '2011-12-12T14:27:31+02:00',
                url: 'http://example.com/diaspora/commits/b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327',
                author: {
                    name: 'Jordi Mallach',
                    email: 'jordi@softcatala.org'
                }
            },
            {
                id: 'da1560886d4f094c3e6c9ef40349f7d38b5d27d7',
                message: 'fixed readme',
                timestamp: '2012-01-03T23:36:29+02:00',
                url: 'http://example.com/diaspora/commits/da1560886d4f094c3e6c9ef40349f7d38b5d27d7',
                author: {
                    name: 'GitLab dev user',
                    email: 'gitlabdev@dv6700.(none)'
                }
            }
        ],
        total_commits_count: 2
    }
  end

  def gitlab_headers
    {
        'Content_Type' => 'application/json'
    }
  end
end
