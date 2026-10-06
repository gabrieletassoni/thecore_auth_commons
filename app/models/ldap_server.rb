class LdapServer < ApplicationRecord
  default_scope { order(priority: :asc) }

  # Associations
  include Api::LdapServer
  include RailsAdmin::LdapServer

  # Validations
  validates :host, presence: true
  validates :base_dn, presence: true

  # Callbacks
  # Users imported from this server outlive it: they become local users, same record and roles,
  # and need a local password set by hand to log in again.
  after_destroy :turn_users_into_local_users

  def test_connection
    # Test the connection to the LDAP server
    ldap = Net::LDAP.new(
      host: host,
      port: port,
      encryption: use_ssl ? :simple_tls : nil,
      auth: {
        method: :simple,
        username: admin_user,
        password: admin_password
      }
    )
    # Perform a simple bind to check the connection
    if ldap.bind
      # Connection successful
      Rails.logger.info "Connection to LDAP server #{host} successful."
    else
      # Connection failed
      Rails.logger.info "Connection to LDAP server #{host} failed: #{ldap.get_operation_result.message}"
    end
  end

  private

  # Destroying the users here used to strip their roles even when the destroy was refused: a
  # User's dependents are destroyed before any later before_destroy guard aborts, and the
  # abort's rollback is swallowed inside this record's own transaction, so it never undid them.
  def turn_users_into_local_users
    User.where(auth_source: "ldap #{id}").update_all(auth_source: "local", updated_at: Time.current)
  end
end
