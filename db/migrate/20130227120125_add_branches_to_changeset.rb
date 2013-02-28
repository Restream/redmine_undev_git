class AddBranchesToChangeset < ActiveRecord::Migration
  def change
    add_column :changesets, :branches, :text unless column_exists? :changesets, :branches
  end
end
