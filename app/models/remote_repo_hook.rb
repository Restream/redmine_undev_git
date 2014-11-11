class RemoteRepoHook < ActiveRecord::Base
  belongs_to :revision, :class_name => 'RemoteRepoRevision', :foreign_key => 'remote_repo_revision_id'
  belongs_to :hook
  belongs_to :issue
  belongs_to :journal

end
