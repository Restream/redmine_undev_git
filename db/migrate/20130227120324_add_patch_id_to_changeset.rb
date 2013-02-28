class AddPatchIdToChangeset < ActiveRecord::Migration
  def change
    add_column :changesets, :patch_id, :string unless column_exists? :changesets, :patch_id
  end
end
