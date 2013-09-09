class ChangeRepositoriesExtraInfoLimit < ActiveRecord::Migration
  def change
    change_column :repositories, :extra_info, :text, :limit => 16777215
  end
end
