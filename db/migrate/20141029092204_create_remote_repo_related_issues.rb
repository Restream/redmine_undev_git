class CreateRemoteRepoRelatedIssues < ActiveRecord::Migration
  def change
    create_table :remote_repo_related_issues do |t|
      t.references :remote_repo_revision
      t.references :issue

      t.datetime :created_at
    end

    add_index :remote_repo_related_issues, :issue_id
  end
end
