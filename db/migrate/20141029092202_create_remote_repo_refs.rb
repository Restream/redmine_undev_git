class CreateRemoteRepoRefs < ActiveRecord::Migration
  def change
    create_table :remote_repo_refs do |t|
      t.references :remote_repo

      t.string :name

      t.datetime :created_at
    end

    add_index :remote_repo_refs, [:remote_repo_id, :name]
  end
end
