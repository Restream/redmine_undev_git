class CreateRemoteRepoSites < ActiveRecord::Migration
  def change
    create_table :remote_repo_sites do |t|
      t.string :type
      t.string :server_name

      t.timestamps
    end
  end
end
