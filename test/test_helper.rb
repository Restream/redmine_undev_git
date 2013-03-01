require File.expand_path(File.dirname(__FILE__) + '../../../../test/test_helper')

require 'tmpdir'

class ActiveSupport::TestCase
  REPOSITORY_PATH = File.join(Rails.root, 'tmp', 'test', 'undev_git_repository')

  def make_temp_dir
    @temp_storage_dir = Dir.mktmpdir('repo')
    Repository::UndevGit.repo_storage_dir = @temp_storage_dir
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
        :new_status_id => 1,
        :new_done_ratio => '100%'
    )
    GlobalHook.create!(
        :branches => 'production',
        :keywords => 'close,fix',
        :new_status_id => 2
    )
    ProjectHook.create!(
        :project_id => 3,
        :repository_id => repository_id,
        :branches => 'master',
        :keywords => 'close,fix',
        :new_status_id => 1,
        :new_done_ratio => '100%'
    )
    ProjectHook.create!(
        :project_id => 3,
        :repository_id => repository_id,
        :branches => 'production',
        :keywords => 'close,fix',
        :new_status_id => 2
    )
    ProjectHook.create!(
        :project_id => 3,
        :branches => 'production',
        :keywords => 'fix',
        :new_status_id => 3
    )
  end
end
