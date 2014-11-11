class RemoteRepoRefsRev < ActiveRecord::Base
  belongs_to :revision, :class_name => 'RemoteRepoRevision', :foreign_key => 'remote_repo_revision_id'
  belongs_to :ref, :class_name => 'RemoteRepoRef', :foreign_key => 'remote_repo_ref_id'
end
