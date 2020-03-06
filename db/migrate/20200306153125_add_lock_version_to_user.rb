class AddLockVersionToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :lock_version, :bigint
  end
end
