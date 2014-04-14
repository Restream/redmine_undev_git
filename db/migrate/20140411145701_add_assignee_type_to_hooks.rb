class AddAssigneeTypeToHooks < ActiveRecord::Migration
  def up
    add_column :hooks, :assignee_type, :string, :default => HookBase::NOBODY
    update "UPDATE hooks SET assignee_type='#{HookBase::NOBODY}' WHERE assignee_type IS NULL AND assigned_to_id IS NULL"
    update "UPDATE hooks SET assignee_type='#{HookBase::USER}' WHERE assigned_to_id IS NOT NULL AND assigned_to_id <> 0"
  end

  def down
    remove_column :hooks, :assignee_type
  end
end
