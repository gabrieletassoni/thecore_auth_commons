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

  # The outcome of #test_connection: success? and, when it failed, the reason in message.
  ConnectionResult = Data.define(:success, :message) do
    def success? = success
  end

  # Binds as the admin user and reports whether that worked, and why not. Never raises for a
  # server it cannot reach or bind to: the RailsAdmin test_ldap_server action shows the result.
  def test_connection
    if admin_user.blank? || admin_password.blank?
      return ConnectionResult.new(success: false, message: "No admin user and password are configured for this server")
    end

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
    if ldap.bind
      Rails.logger.info "Connection to LDAP server #{host} successful."
      ConnectionResult.new(success: true, message: nil)
    else
      reason = ldap.get_operation_result.message
      Rails.logger.info "Connection to LDAP server #{host} failed: #{reason}"
      ConnectionResult.new(success: false, message: reason)
    end
  rescue Net::LDAP::Error => e
    Rails.logger.info "Connection to LDAP server #{host} failed: #{e.message}"
    ConnectionResult.new(success: false, message: e.message)
  end

  private

  # Destroying the users here used to strip their roles even when the destroy was refused: a
  # User's dependents are destroyed before any later before_destroy guard aborts, and the
  # abort's rollback is swallowed inside this record's own transaction, so it never undid them.
  def turn_users_into_local_users
    User.where(auth_source: "ldap #{id}").update_all(auth_source: "local", updated_at: Time.current)
  end
end
