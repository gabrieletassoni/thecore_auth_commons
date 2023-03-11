# frozen_string_literal: true

# Rails supports :uuid with PostgreSQL.
# For Sqlite users it's advisable to store it in a :string.
class UseStringForUuids < ActiveRecord::Migration[6.1]
  def change
    change_column :users, :access_token, :string, limit: 36
  end
end
