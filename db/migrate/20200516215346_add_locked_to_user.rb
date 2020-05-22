class AddLockedToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :locked, :boolean, null: false, default: false
  end
end
