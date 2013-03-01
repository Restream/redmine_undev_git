class CreateHooks < ActiveRecord::Migration
  def change
    create_table :hooks, :force => true do |t|
      t.string :type, :null => false
      t.references :project
      t.references :repository
      t.integer :position
      t.string :branches, :null => false
      t.string :keywords, :null => false
      t.references :new_status
      t.integer :new_done_ratio
    end
  end
end
