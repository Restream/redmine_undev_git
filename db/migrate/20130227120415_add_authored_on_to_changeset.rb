class AddAuthoredOnToChangeset < ActiveRecord::Migration
  def change
    add_column :changesets, :authored_on, :datetime unless column_exists? :changesets, :authored_on
  end
end
