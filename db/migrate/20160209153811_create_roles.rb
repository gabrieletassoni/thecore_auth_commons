class CreateRoles < ActiveRecord::Migration[7.0]
  def change
    create_table :roles, if_not_exists: true do |t|
      t.string :name
      t.bigint :lock_version

      t.timestamps
    end
    add_index :roles, :name, unique: true, if_not_exists: true
  end
end
