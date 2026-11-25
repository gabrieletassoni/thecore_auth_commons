# The LDAP bind password is a secret: an index on it is a second copy of it, sorted (host ADR 0046
# point 10, host Odoo #6084). Down restores the index of CreateLdapServers.
class RemoveAdminPasswordIndexFromLdapServers < ActiveRecord::Migration[7.2]
  def up
    remove_index :ldap_servers, :admin_password, if_exists: true
  end

  def down
    add_index :ldap_servers, :admin_password, if_not_exists: true
  end
end
