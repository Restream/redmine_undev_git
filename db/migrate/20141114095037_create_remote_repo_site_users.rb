class CreateRemoteRepoSiteUsers < ActiveRecord::Migration
  def change
    create_table :remote_repo_site_users do |t|
      t.references :remote_repo_site
      t.string :email
      t.references :user

      t.timestamps
    end
    add_index :remote_repo_site_users, :remote_repo_site_id
    add_index :remote_repo_site_users, [:remote_repo_site_id, :email]
  end
end
