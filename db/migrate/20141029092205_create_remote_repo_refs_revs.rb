class CreateRemoteRepoRefsRevs < ActiveRecord::Migration
  def change
    create_table :remote_repo_refs_revs do |t|
      t.references :remote_repo_revision
      t.references :remote_repo_ref

      t.datetime :created_at
    end

    add_index :remote_repo_refs_revs, :remote_repo_revision_id
  end
end
