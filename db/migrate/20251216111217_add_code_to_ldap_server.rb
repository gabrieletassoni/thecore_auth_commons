class AddCodeToLdapServer < ActiveRecord::Migration[7.2]
  def change
    add_column :ldap_servers, :code, :string
    add_index :ldap_servers, :code
  end
end
