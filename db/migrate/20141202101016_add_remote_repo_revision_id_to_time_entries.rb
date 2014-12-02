class AddRemoteRepoRevisionIdToTimeEntries < ActiveRecord::Migration
  def change
    add_column :time_entries, :remote_repo_revision_id, :integer
  end
end
