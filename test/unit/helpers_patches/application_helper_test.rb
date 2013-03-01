require File.expand_path( '../../../test_helper', __FILE__ )

class ApplicationHelperTest < ActionView::TestCase
  include ERB::Util

  fixtures :projects

  def setup
    super
    make_temp_dir
    @project = Project.find(3)
    @repository = create_test_repository(:project => @project)
    @named_repository = create_test_repository(:project => @project,
                                               :identifier => 'named')
    fake_rev = '1234567890123456789012345678901234567890'
    branches = Array.new(15) { |i| "branch#{i}" }
    @changeset = Changeset.new(
        :repository   => @repository,
        :revision     => fake_rev,
        :scmid        => fake_rev,
        :branches     => branches
    )
  end

  def teardown
    remove_temp_dir
  end

  def test_link_to_branch
    branch = 'test_branch'
    link = "<a href=\"/projects/#{@project.identifier}/repository?branch=#{branch}\">#{branch}</a>"
    link_named = "<a href=\"/projects/#{@project.identifier}/repository/#{@named_repository.identifier}?branch=#{branch}\">#{branch}</a>"
    assert_equal link, link_to_branch(branch, @repository)
    assert_equal link_named, link_to_branch(branch, @named_repository)
  end

  def test_link_to_branch_with_rev
    branch = 'test_branch'
    rev = 'fba357b886984ee71185ad2065e65fc0417d9b92'
    link = "<a href=\"/projects/#{@project.identifier}/repository?branch=#{branch}&amp;rev=#{rev}\">#{branch}</a>"
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

end
