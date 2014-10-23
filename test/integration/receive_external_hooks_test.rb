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

  def test_fetch_after_github_push_hook
    repository = create_test_repository(:project => @project, :url => 'https://github.com/octokitty/testing.git')
    assert repository
    Workers::RepositoryFetcher.expects(:defer).with(repository.id).at_least_once
    post '/github_hooks', github_push_payload.to_json, github_push_headers
    assert_response :success
  end

  def test_success_on_github_ping_hook
    post '/github_hooks', github_ping_payload.to_json, github_ping_headers
    assert_response :success
  end

  def test_success_on_github_ping_hook_when_login_requred
    Setting.login_required = '1'
    post '/github_hooks', github_ping_payload.to_json, github_ping_headers
    assert_response :success
  end

  def test_fetch_after_bitbucket_push_hook
    repository = create_test_repository(:project => @project, :url => 'https://bitbucket.org/test/dt_fetch.git')
    assert repository
    Workers::RepositoryFetcher.expects(:defer).with(repository.id).at_least_once
    post '/bitbucket_hooks', :payload => bitbucket_payload.to_json
    assert_response :success
  end

  # working with remote repositories

  def test_create_remote_repo_after_gitlab_push_hook
    post '/gitlab_hooks', gitlab_payload.to_json, gitlab_headers
    assert_response :success
    repository = RemoteRepo.find_by_url(gitlab_payload[:repository][:url])
    assert repository
    assert repository.site
    assert repository.site.is_a?(RemoteRepoSite::Gitlab)
  end

  # hooks payloads

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

  def github_push_payload
    {
        after: "1481a2de7b2a7d02428ad93446ab166be7793fbb",
        before: "17c497ccc7cca9c2f735aa07e9e3813060ce9a6a",
        commits: [
            {
                added: [

                ],
                author: {
                    email: "lolwut@noway.biz",
                    name: "Garen Torikian",
                    username: "octokitty"
                },
                committer: {
                    email: "lolwut@noway.biz",
                    name: "Garen Torikian",
                    username: "octokitty"
                },
                distinct: true,
                id: "c441029cf673f84c8b7db52d0a5944ee5c52ff89",
                message: "Test",
                modified: [
                    "README.md"
                ],
                removed: [

                ],
                timestamp: "2013-02-22T13:50:07-08:00",
                url: "https://github.com/octokitty/testing/commit/c441029cf673f84c8b7db52d0a5944ee5c52ff89"
            },
            {
                added: [

                ],
                author: {
                    email: "lolwut@noway.biz",
                    name: "Garen Torikian",
                    username: "octokitty"
                },
                committer: {
                    email: "lolwut@noway.biz",
                    name: "Garen Torikian",
                    username: "octokitty"
                },
                distinct: true,
                id: "36c5f2243ed24de58284a96f2a643bed8c028658",
                message: "This is me testing the windows client.",
                modified: [
                    "README.md"
                ],
                removed: [

                ],
                timestamp: "2013-02-22T14:07:13-08:00",
                url: "https://github.com/octokitty/testing/commit/36c5f2243ed24de58284a96f2a643bed8c028658"
            },
            {
                added: [
                    "words/madame-bovary.txt"
                ],
                author: {
                    email: "lolwut@noway.biz",
                    name: "Garen Torikian",
                    username: "octokitty"
                },
                committer: {
                    email: "lolwut@noway.biz",
                    name: "Garen Torikian",
                    username: "octokitty"
                },
                distinct: true,
                id: "1481a2de7b2a7d02428ad93446ab166be7793fbb",
                message: "Rename madame-bovary.txt to words/madame-bovary.txt",
                modified: [

                ],
                removed: [
                    "madame-bovary.txt"
                ],
                timestamp: "2013-03-12T08:14:29-07:00",
                url: "https://github.com/octokitty/testing/commit/1481a2de7b2a7d02428ad93446ab166be7793fbb"
            }
        ],
        compare: "https://github.com/octokitty/testing/compare/17c497ccc7cc...1481a2de7b2a",
        created: false,
        deleted: false,
        forced: false,
        head_commit: {
            added: [
                "words/madame-bovary.txt"
            ],
            author: {
                email: "lolwut@noway.biz",
                name: "Garen Torikian",
                username: "octokitty"
            },
            committer: {
                email: "lolwut@noway.biz",
                name: "Garen Torikian",
                username: "octokitty"
            },
            distinct: true,
            id: "1481a2de7b2a7d02428ad93446ab166be7793fbb",
            message: "Rename madame-bovary.txt to words/madame-bovary.txt",
            modified: [

            ],
            removed: [
                "madame-bovary.txt"
            ],
            timestamp: "2013-03-12T08:14:29-07:00",
            url: "https://github.com/octokitty/testing/commit/1481a2de7b2a7d02428ad93446ab166be7793fbb"
        },
        pusher: {
            email: "lolwut@noway.biz",
            name: "Garen Torikian"
        },
        ref: "refs/heads/master",
        repository: {
            created_at: 1332977768,
            description: "",
            fork: false,
            forks: 0,
            has_downloads: true,
            has_issues: true,
            has_wiki: true,
            homepage: "",
            id: 3860742,
            language: "Ruby",
            master_branch: "master",
            name: "testing",
            open_issues: 2,
            owner: {
                email: "lolwut@noway.biz",
                name: "octokitty"
            },
            private: false,
            pushed_at: 1363295520,
            size: 2156,
            stargazers: 1,
            url: "https://github.com/octokitty/testing",
            watchers: 1
        }
    }
  end

  def github_push_headers
    {
        'CONTENT_TYPE' => 'application/json',
        'HTTP_USER_AGENT' => 'GitHub Hookshot 2636b5a',
        'HTTP_X_GITHUB_DELIVERY' => '4d70b218-ec96-11e3-86ba-0eba6417d40d',
        'HTTP_X_GITHUB_EVENT' => 'push'
    }
  end

  def github_ping_payload
    {
        'zen' => 'Avoid administrative distraction.',
        'hook_id' => 2370832
    }
  end

  def github_ping_headers
    {
        'CONTENT_TYPE' => 'application/json',
        'HTTP_USER_AGENT' => 'GitHub Hookshot 2636b5a',
        'HTTP_X_GITHUB_DELIVERY' => '4d70b218-ec96-11e3-86ba-0eba6417d40d',
        'HTTP_X_GITHUB_EVENT' => 'ping'
    }
  end

  def bitbucket_payload
    {
        repository: {
            website: '',
            fork: false,
            name: 'dt_fetch',
            scm: 'git',
            owner: 'test',
            absolute_url: '/test/dt_fetch/',
            slug: 'dt_fetch',
            is_private: false
        },
        truncated: false,
        commits: [
            {
                node: '81c83664d120',
                files: [
                    {type: 'added', file: 'update5.txt'}
                ],
                raw_author: 'Test <test@example.com>',
                utctimestamp: '2014-06-06 07:04:38+00:00',
                author: 'test',
                timestamp: '2014-06-06 09:04:38',
                raw_node: '81c83664d120ce05c91b7259b70c02ebc64edd52',
                parents: ['75d5e5aef45a'],
                branch: 'master',
                message: 'update 5',
                revision: nil,
                size: -1
            }
        ],
        canon_url: 'https://bitbucket.org',
        user: 'test'
    }
  end
end
