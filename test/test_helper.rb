require File.expand_path(File.dirname(__FILE__) + '../../../../test/test_helper')

require 'tmpdir'

factories_path = File.expand_path(File.dirname(__FILE__) + '/factories')
unless FactoryGirl.definition_file_paths.include? factories_path
  FactoryGirl.definition_file_paths << factories_path
  FactoryGirl.reload
end

class ActiveSupport::TestCase
  include FactoryGirl::Syntax::Methods

  REPOSITORY_PATH = File.join(Rails.root, 'tmp', 'test', 'undev_git_repository')

  # these repositories looks like:
  # http://git-scm.com/book/en/Git-Branching-Rebasing#More-Interesting-Rebases
  R_BEFORE_REBASE_PATH = File.join(Rails.root, 'tmp', 'test', 'rebase_test_before.git')
  R_AFTER_REBASE_PATH = File.join(Rails.root, 'tmp', 'test', 'rebase_test_after.git')

  # testing hooks
  RD1 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r1.git')
  RD2 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r2.git')
  RD3 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r3.git')
  RD4 = File.join(Rails.root, 'tmp', 'test', 'hooks_every_branch_r4.git')

  CMT1 = '1a81e3a76c1fd2a5eef3c63d7b9ff36bf836548c'
  CMT2 = '725bc91aabb76019be9d0d8714e9aef15bd9753c'
  CMT3 = 'a578eac0e2f36e609fe49a5eec2f4386ab71cf24'
  CMT4 = '57096e16ce4541e2f02c330ffe24551f91f90cae'
  CMT5 = '0b652ac1bc8b9424230701dcc28511cd47df1c32'
  CMT6 = 'c18df3f4dca6fa808f19a3a60047274dddc7280c'
  CMT7 = '0d8c70c242b62e1e35fdbf2c5a35be3f1700fd40'
  CMT8 = '90045e487f0d5d966c446882965e543bcbbd353e'
  CMT9 = 'c25b5dd0f99b3cb2d102c9893de24b8c16797f0c'

# R4
#    *          c9 Merge branch 'develop'; hook9 #5
#    |\
# ----- -- ------------------------------------------------------------------------
# R3 |  |
#    |  *       c8 Merge branch 'feature' into develop; hook8 #5
#    |  |\
# ----- -- -- ----------------------------------------------------------------------
# R2 |  |  |  * c7 Merge branch 'feature' into staging; hook7 #5
#    |  |  | /|
#    |  |  || |
#    |  |  |/ |
#    |  |  *  | c6 hook6 #5
# ----- -- -- ----------------------------------------------------------------------
# R1 |  |  |  * c5 hook5 #5
#    |  |  |/
#    |  |  *    c4 hook4 #5
#    |  |  *    c3 hook3 #5
#    |  |/
#    |  *       c2 hook2 #5
#    |/
#    *          c1 hook1 #5
#
#    m  d  f  s
#    a  e  e  t
#    s  v  a  a
#    t  e  t  g
#    e  l  u  i
#    r  o  r  n
#       p  e  g
#
#  Hooks:
#    keywords       branches      new %     hook fired on
#    hook1          *             10        R1
#
#    hook2_1        develop       21        R1
#    hook2_2        feature       22        R1
#    hook2_3        staging       23        R1
#    hook2_4        master        24        R4
#
#    hook3_1        develop       31        R3
#    hook3_2        master        32        R4


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

  def stubs_scm_revisions(revisions)
    RedmineUndevGit::Services::GitAdapter.any_instance.stubs(:revisions).returns(revisions)
    branches = [RedmineUndevGit::Services::GitBranchRef.new('master', '1')]
    RedmineUndevGit::Services::GitAdapter.any_instance.stubs(:branches).returns(branches)
  end

  def fake_revision(attrs = {})
    @clock ||= attrs[:clock] || (Time.now - 1.year)
    r = RedmineUndevGit::Services::GitRevision.new
    r.sha     = fake_sha
    r.aname   = attrs[:aname]   || 'Redmine Admin'
    r.aemail  = attrs[:aemail]  || 'admin@somenet.foo'
    r.adate   = attrs[:adate]   || @clock
    r.cname   = attrs[:cname]   || r.aname
    r.cemail  = attrs[:cemail]  || r.aemail
    r.cdate   = attrs[:cdate]   || @clock
    r.message = attrs[:message] || 'test fixes #5 @1h'
    @clock = @clock + 1.hour
    r
  end

  def fake_sha
    Digest::SHA1.hexdigest rand(1000000).to_s
  end
end
