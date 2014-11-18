class RemoteRepoRevision < ActiveRecord::Base
  belongs_to :repo, :class_name => 'RemoteRepo', :foreign_key => 'remote_repo_id'
  belongs_to :author, :class_name => 'User'
  belongs_to :committer, :class_name => 'User'

  has_and_belongs_to_many :related_issues, :class_name => 'Issue', :join_table => 'remote_repo_related_issues'
  has_many :applied_hooks, :class_name => 'RemoteRepoHook'

  validates :repo, :presence => true
  validates :sha, :presence => true

  def uri
    [repo.uri.chomp('/'), 'commit', sha].join('/')
  end

  def redmine_uri
    "\"#{short_sha}\":#{uri}"
  end

  def short_sha
    sha[0..7]
  end

end
