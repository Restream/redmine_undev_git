require File.expand_path(File.dirname(__FILE__) + '../../../../test/test_helper')

require 'tmpdir'

class ActiveSupport::TestCase
  REPOSITORY_PATH = File.join(Rails.root, 'tmp', 'test', 'undev_git_repository')

  # these repositories looks like:
  # http://git-scm.com/book/en/Git-Branching-Rebasing#More-Interesting-Rebases
  R_BEFORE_REBASE_PATH = File.join(Rails.root, 'tmp', 'test', 'rebase_test_before.git')
  R_AFTER_REBASE_PATH = File.join(Rails.root, 'tmp', 'test', 'rebase_test_after.git')

  def make_temp_dir
    @temp_storage_dir = Dir.mktmpdir('repo')
    Repository::UndevGit.repo_storage_dir = @temp_storage_dir
    RedmineUndevGit::Services::RemoteRepoFetch.repo_storage_dir = @temp_storage_dir
  end

  def remove_temp_dir
    FileUtils.remove_entry_secure(@temp_storage_dir)
  end

  def create_test_repository(options = {})
    raise 'create temp dir first by calling make_temp_dir' unless @temp_storage_dir
    options[:project] = Project.find(3) unless options.key?(:project)
    options[:url] = REPOSITORY_PATH unless options.key?(:url)
    options[:path_encoding] = 'ISO-8859-1' unless options.key?(:path_encoding)
    Repository::UndevGit.create(options)
  end
  
  def create_hooks!(options = {})
    repository_id = options[:repository_id] || 1
    GlobalHook.create!(
        :branches => 'master',
        :keywords => 'close,fix',
        :status_id => 1,
        :done_ratio => '90%'
    )
    GlobalHook.create!(
        :branches => 'production',
        :keywords => 'close,fix,closes',
        :status_id => 2,
        :done_ratio => '80%'
    )
    ProjectHook.create!(
        :project_id => 3,
        :repository_id => repository_id,
        :branches => 'master',
        :keywords => 'close,fix',
        :status_id => 1,
        :done_ratio => '70%'
    )
    ProjectHook.create!(
        :project_id => 3,
        :repository_id => repository_id,
        :branches => 'production',
        :keywords => 'close,fix',
        :status_id => 2,
        :done_ratio => '60%'
    )
    ProjectHook.create!(
        :project_id => 3,
        :branches => 'production',
        :keywords => 'fix',
        :status_id => 3,
        :done_ratio => '50%'
    )
  end

  def create_rebased_repository
    repo = create_test_repository(:url => R_BEFORE_REBASE_PATH,
                                  :path_encoding => 'UTF-8')
    repo.fetch_changesets

    # replace origin url to fetch rebased commits
    repo.scm.send :git_cmd, ['remote', 'set-url', 'origin', R_AFTER_REBASE_PATH]

    repo.fetch_changesets

    repo
  end

  def rebased_changesets(repo = nil)
    repo ||= create_rebased_repository

    cs = {
        :c1 => '21d88b7',
        :c2 => 'ac7080c',
        :c3 => '8455e27',
        :c4 => '40a5965',
        :c5 => '43784cc',
        :c6 => 'b278ae2',
        :c8 => 'd2815cb',
        :c9 => 'ad445de',
        :c10 => '2b91d81',
        # rebased
        :c3r => 'c906d8f',
        :c4r => '1bb0a5f',
        :c8r => 'e679660',
        :c9r => '3cd80ef',
        :c10r => 'feeb6b1',
    }

    cs.each_key { |key| cs[key] = repo.find_changeset_by_name(cs[key]) }
  end
end
