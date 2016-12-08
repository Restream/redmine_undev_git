require File.expand_path('../../../test_helper', __FILE__)

class UndevGitHelperTest < ActionView::TestCase
  include ERB::Util
  include UndevGitHelper

  fixtures :projects, :issues, :users, :email_addresses

  def setup
    super
    make_temp_dir
    @project          = Project.find(3)
    @repository       = create_test_repository(project: @project)
    @named_repository = create_test_repository(project: @project,
      identifier:                                       'named')
    fake_rev          = '1234567890123456789012345678901234567890'
    branches          = Array.new(15) { |i| "branch#{i}" }
    @changeset        = Changeset.new(
      repository: @repository,
      revision:   fake_rev,
      scmid:      fake_rev,
      branches:   branches
    )
  end

  def teardown
    remove_temp_dir
  end

  def test_link_to_repository
    @project    = Project.find(2)
    exp_link    = "/projects/#{@repository.project.identifier}/repository"
    result_link = link_to_repository(@repository)
    assert_match exp_link, result_link
    assert_match @repository.name, result_link
  end

  def test_link_to_named_repository
    @project          = Project.find(2)
    exp_link_named    = "/projects/#{@named_repository.project.identifier}/repository/#{@named_repository.identifier}"
    result_named_link = link_to_repository(@named_repository)
    assert_match exp_link_named, result_named_link
    assert_match @named_repository.name, result_named_link
  end

  def test_link_to_branch
    branch     = 'test_branch'
    link       = "<a href=\"/projects/#{@project.identifier}/repository?branch=#{branch}\">#{branch}</a>"
    link_named = "<a href=\"/projects/#{@project.identifier}/repository/#{@named_repository.identifier}?branch=#{branch}\">#{branch}</a>"
    assert_equal link, link_to_branch(branch, @repository)
    assert_equal link_named, link_to_branch(branch, @named_repository)
  end

  def test_link_to_branch_with_rev
    branch     = 'test_branch'
    rev        = 'fba357b886984ee71185ad2065e65fc0417d9b92'
    link       = "<a href=\"/projects/#{@project.identifier}/repository?branch=#{branch}&amp;rev=#{rev}\">#{branch}</a>"
    link_named = "<a href=\"/projects/#{@project.identifier}/repository/#{@named_repository.identifier}?branch=#{branch}&amp;rev=#{rev}\">#{branch}</a>"
    assert_equal link, link_to_branch(branch, @repository, rev)
    assert_equal link_named, link_to_branch(branch, @named_repository, rev)
  end

  def test_changeset_branches
    res = changeset_branches(@changeset)
    # (branch1[; branchN]) all 15 branches
    assert_match %r{\A\((<a href(.*)<\/a>(;\s)?){15}\)\z}, res
  end

  def test_changeset_branches_max_0
    res = changeset_branches(@changeset, 0)
    # (branch1[; branchN]) all 15 branches
    assert_match %r{\A\((<a href(.*)<\/a>(;\s)?){15}\)\z}, res
  end

  def test_changeset_branches_max_5
    res = changeset_branches(@changeset, 5)
    # (branch1[; branchN]...) only 5 branches and '...'
    assert_match %r{\A\((<a href(.*)<\/a>(;\s)?){5}\.{3}\)\z}, res
  end

  def test_changeset_branches_max_20
    res = changeset_branches(@changeset, 20)
    # (branch1[; branchN]) all 15 branches
    assert_match %r{\A\((<a href(.*)<\/a>(;\s)?){15}\)\z}, res
  end

  def test_link_to_remote_revision
    branches = %w{master develop staging}
    repo     = create_remote_repo
    revision = repo.revisions.create!(
      sha:       '83ca5fd',
      committer: User.find(1),
      message:   'reference #1'
    )
    branches.each do |branch|
      ref = repo.refs.create!(name: branch)
      revision.refs << ref
    end
    link     = link_to_remote_revision(revision)
    branches = links_to_remote_branches(revision)
    assert_match "href=\"https://gitlab.com/commit/83ca5fd\"", link
    assert_match branches, link
    assert_match "href=\"https://gitlab.com/\"", link
  end

  def test_links_to_remote_branches
    branches = %w{master develop staging}
    repo     = create_remote_repo
    revision = repo.revisions.create!(
      sha:       '83ca5fd',
      committer: User.find(1),
      message:   'reference #1'
    )
    branches.each do |branch|
      ref = repo.refs.create!(name: branch)
      revision.refs << ref
    end
    links = links_to_remote_branches(revision)
    branches.each do |branch|
      exp_link = "href=\"https://gitlab.com/commits/#{branch}\""
      assert_match exp_link, links
    end
  end

  def create_remote_repo
    site = RemoteRepoSite::Gitlab.create!(server_name: 'gitlab.com')
    site.repos.create!(url: REPOSITORY_PATH)
  end

end
