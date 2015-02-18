class AddAuthorEmailToRemoteRepoHooks < ActiveRecord::Migration
  def change
    remove_column :remote_repo_hooks, :author_string
    add_column :remote_repo_hooks, :author_email, :string
  end
end
