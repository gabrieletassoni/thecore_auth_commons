class AddLdapMatchFieldsToLdapServer < ActiveRecord::Migration[7.2]
  def change
    add_column :ldap_servers, :name, :string
    add_index :ldap_servers, :name
    add_column :ldap_servers, :surname, :string
    add_index :ldap_servers, :surname
    add_column :ldap_servers, :phone, :string
    add_index :ldap_servers, :phone
  end
end
