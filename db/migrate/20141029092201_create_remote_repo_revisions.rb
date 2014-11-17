class CreateRemoteRepoRevisions < ActiveRecord::Migration
  def change
    create_table :remote_repo_revisions do |t|
      t.references :remote_repo
      t.references :author
      t.references :committer

      t.string :sha
      t.string :author_string
      t.string :committer_string
      t.text :message
      t.datetime :author_date
      t.datetime :committer_date

      t.datetime :created_at
    end

    add_index :remote_repo_revisions, :remote_repo_id
    add_index :remote_repo_revisions, [:remote_repo_id, :sha]
  end
end
