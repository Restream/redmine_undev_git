class RemoteRepoRevision < ActiveRecord::Base
  belongs_to :repo, :class_name => 'RemoteRepo'
  has_and_belongs_to_many :related_issues, :class_name => 'Issue', :join_table => 'remote_repo_related_issues'
end
