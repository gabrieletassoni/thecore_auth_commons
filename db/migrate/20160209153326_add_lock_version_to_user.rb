class AddLockVersionToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :lock_version, :bigint, if_not_exists: true
  end
end
