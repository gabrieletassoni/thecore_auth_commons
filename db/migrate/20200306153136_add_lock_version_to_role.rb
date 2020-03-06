class AddLockVersionToRole < ActiveRecord::Migration[6.0]
  def change
    add_column :roles, :lock_version, :bigint
  end
end
