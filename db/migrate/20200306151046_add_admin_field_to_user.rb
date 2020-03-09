class AddAdminFieldToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :admin, :boolean, null: false, default: false
    add_column :users, :username, :string, null: false, default: ""

    add_index :users, :username, unique: true
  end
end
