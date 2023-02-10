class AddTrackableToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :sign_in_count, :bigint, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :current_sign_in_ip, :string
    add_column :users, :last_sign_in_ip, :string
  end
end