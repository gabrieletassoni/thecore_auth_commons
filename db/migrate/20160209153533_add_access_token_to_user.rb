class AddAccessTokenToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :encrypted_access_token, :string, if_not_exists: true
  end
end
