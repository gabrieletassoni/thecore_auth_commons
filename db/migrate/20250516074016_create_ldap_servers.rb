class CreateLdapServers < ActiveRecord::Migration[7.2]
  def change
    create_table :ldap_servers do |t|
      t.string :host, null: false
      t.integer :port, default: 389
      t.string :base_dn, null: false
      t.string :admin_user
      t.string :admin_password
      t.integer :priority, default: 1
      t.boolean :use_ssl, default: false
      t.string :auth_field, default: "userPrincipalName"

      t.timestamps
    end
    add_index :ldap_servers, :host
    add_index :ldap_servers, :base_dn
    add_index :ldap_servers, :admin_user
    add_index :ldap_servers, :admin_password
    add_index :ldap_servers, :auth_field
  end
end
