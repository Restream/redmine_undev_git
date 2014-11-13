require File.expand_path('../../../../test_helper', __FILE__)

class RedmineUndevGit::Services::GitAdapterTest < ActiveSupport::TestCase

  def setup
    make_temp_dir
    @klass = RedmineUndevGit::Services::GitAdapter
  end

  def teardown
    remove_temp_dir
  end

  def test_git_version
    @klass.stubs(:shell_read).returns("git version 1.7.3\n")
    @klass.instance_variable_set :@git_version, nil
    version = @klass.git_version
    assert version
    assert_equal [1, 7, 3], version
  end

  def test_git_version_above
    @klass.stubs(:shell_read).returns("git version 1.7.3\n")
    @klass.instance_variable_set :@git_version, nil
    assert @klass.git_version_above_or_equal?([1,7,2])
    assert @klass.git_version_above_or_equal?([1,7,3])
    refute @klass.git_version_above_or_equal?([1,7,4])
    refute @klass.git_version_above_or_equal?([2,1,2])
  end

  def test_repository_exists_returns_false_unless_repo_url_directory_exists
    adapter = @klass.new('dummy', '/nonexistencepath')
    refute adapter.repository_exists?
  end

  def test_repository_exists_returns_true_if_git_repo_exists
    adapter = @klass.new('dummy', REPOSITORY_PATH)
    assert adapter.repository_exists?
  end

  def test_clone_repository
    root_url = File.join(@temp_storage_dir, 'remote_test')
    adapter = @klass.new(REPOSITORY_PATH, root_url)
    adapter.clone_repository
    assert adapter.repository_exists?
  end

  def test_branches
    root_url = File.join(@temp_storage_dir, 'remote_test')
    adapter = @klass.new(REPOSITORY_PATH, root_url)
    adapter.clone_repository
    branches = adapter.branches
    assert branches
    assert branches.is_a?(Array)
    branches = branches.map { |b| "#{b.revision[0..6]}_#{b.name}" }.sort
    exp_branches = %w{
      1ca7f5e_latin-1-path-encoding
      2a68215_issue-8857
      67e7792_test-latin-1
      83ca5fd_master
      83ca5fd_master-20120212
      fba357b_test_branch
    }
    assert_equal exp_branches, branches
  end

end
