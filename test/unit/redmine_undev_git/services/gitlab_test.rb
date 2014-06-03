require File.expand_path('../../../../test_helper', __FILE__)

class RedmineUndevGit::Services::GitlabTest < ActiveSupport::TestCase

  def test_git_urls_from_request
    RedmineUndevGit::Services::Gitlab.stubs(:web_hook_from_request).returns(
        gitlab_payload('git@example.com:path_to/diaspora.git')
    )
    urls = RedmineUndevGit::Services::Gitlab.git_urls_from_request('stubbed')
    assert_include 'git@example.com:path_to/diaspora.git', urls
    assert_include 'https://example.com/path_to/diaspora.git', urls
    assert_include 'git://example.com/path_to/diaspora.git', urls
  end

  def test_assert_service_error_on_wrong_url
    assert_raise RedmineUndevGit::Services::WrongRepoUrl do
      RedmineUndevGit::Services::Gitlab.stubs(:web_hook_from_request).returns(
          gitlab_payload('git@example.com/path_to/diaspora.git')
      )
      RedmineUndevGit::Services::Gitlab.git_urls_from_request('stubbed')
    end
  end

  def gitlab_payload(repo_url = 'git@example.com:diaspora.git')
    HashWithIndifferentAccess.new(
        before: '95790bf891e76fee5e1747ab589903a6a1f80f22',
        after: 'da1560886d4f094c3e6c9ef40349f7d38b5d27d7',
        ref: 'refs/heads/master',
        user_id: 4,
        user_name: 'John Smith',
        project_id: 15,
        repository: {
            name: 'Diaspora',
            url: repo_url,
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
    )
  end

end
