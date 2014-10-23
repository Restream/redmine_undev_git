class CreateRemoteRepos < ActiveRecord::Migration
  def change
    create_table :remote_repos do |t|
      t.references :site
      t.string :url
      t.string :root_url

      t.timestamps
    end
    add_index :remote_repos, :site_id
  end
end
