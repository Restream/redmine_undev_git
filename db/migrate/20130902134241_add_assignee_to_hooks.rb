class AddAssigneeToHooks < ActiveRecord::Migration
  def change
    add_column :hooks, :new_assigned_to_id, :integer
  end
end
