class AddLockedToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :locked, :boolean, null: false, default: false, if_not_exists: true
  end
end
