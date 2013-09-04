class RemovePrefixNewFromHooksColumns < ActiveRecord::Migration
  def change
    rename_column :hooks, :new_status_id, :status_id
    rename_column :hooks, :new_done_ratio, :done_ratio
    rename_column :hooks, :new_assigned_to_id, :assigned_to_id
  end
end
