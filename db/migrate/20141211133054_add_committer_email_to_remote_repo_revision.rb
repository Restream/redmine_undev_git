class AddCommitterEmailToRemoteRepoRevision < ActiveRecord::Migration
  def change
    remove_column :remote_repo_revisions, :committer_string
    remove_column :remote_repo_revisions, :author_string
    add_column :remote_repo_revisions, :committer_email, :string
    add_column :remote_repo_revisions, :committer_name, :string
    add_column :remote_repo_revisions, :author_email, :string
    add_column :remote_repo_revisions, :author_name, :string
  end
end
