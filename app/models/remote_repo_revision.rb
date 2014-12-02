class RemoteRepoRevision < ActiveRecord::Base
  belongs_to :repo, :class_name => 'RemoteRepo', :foreign_key => 'remote_repo_id'
  belongs_to :author, :class_name => 'User'
  belongs_to :committer, :class_name => 'User'

  has_and_belongs_to_many :related_issues, :class_name => 'Issue', :join_table => 'remote_repo_related_issues'
  has_and_belongs_to_many :refs, :class_name => 'RemoteRepoRef', :join_table => 'remote_repo_refs_revs'
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

  def branches
    refs.map(&:name)
  end

  def ensure_issue_is_related(issue)
    related_issues << issue unless related_issues.exists?(issue)
  end

end
