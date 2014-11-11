class CreateRemoteRepoHooks < ActiveRecord::Migration
  def change
    create_table :remote_repo_hooks do |t|
      t.references :remote_repo_revision
      t.references :hook
      t.references :issue
      t.references :journal

      t.datetime :created_at
    end

    add_index :remote_repo_hooks, :issue_id
  end
end
