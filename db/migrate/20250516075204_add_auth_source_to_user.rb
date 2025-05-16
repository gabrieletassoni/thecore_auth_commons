class AddAuthSourceToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :auth_source, :string, null: false, default: 'local'
    add_index :users, :auth_source

    # Fill the new column with the default value for existing users
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE users
          SET auth_source = 'local'
          WHERE auth_source IS NULL
        SQL
      end
    end
  end
end
