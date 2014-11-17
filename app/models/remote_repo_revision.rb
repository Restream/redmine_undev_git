class RemoteRepoRevision < ActiveRecord::Base
  belongs_to :repo, :class_name => 'RemoteRepo'
  belongs_to :author, :class_name => 'User'
  belongs_to :committer, :class_name => 'User'

  has_and_belongs_to_many :related_issues, :class_name => 'Issue', :join_table => 'remote_repo_related_issues'
  has_many :applied_hooks, :class_name => 'RemoteRepoHook'
end
