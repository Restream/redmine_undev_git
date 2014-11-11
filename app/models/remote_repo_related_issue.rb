class RemoteRepoRelatedIssue < ActiveRecord::Base
  belongs_to :revision, :class_name => 'RemoteRepoRevision'
  belongs_to :issue
end
