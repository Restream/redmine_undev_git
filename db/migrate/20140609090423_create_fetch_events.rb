class CreateFetchEvents < ActiveRecord::Migration
  def change
    create_table :fetch_events do |t|
      t.references :repository
      t.boolean :successful, :null => false
      t.float :duration, :null => false
      t.string :error_message
      t.timestamps
    end
    add_index :fetch_events, :repository_id
  end
end
