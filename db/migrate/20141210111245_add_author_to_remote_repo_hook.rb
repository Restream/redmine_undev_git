class AddAuthorToRemoteRepoHook < ActiveRecord::Migration
  def change
    add_column :remote_repo_hooks, :author_string, :string
    add_column :remote_repo_hooks, :author_date, :datetime
    add_column :remote_repo_hooks, :keyword, :string
    add_column :remote_repo_hooks, :branch, :string
  end
end
