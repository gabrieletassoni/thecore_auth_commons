class LdapServer < ApplicationRecord
  default_scope { order(priority: :asc) }

  # Associations
  include Api::LdapServer
  include RailsAdmin::LdapServer

  # Validations
  validates :host, presence: true
  validates :base_dn, presence: true

  # Callbacks
  # After the record is actually deleted from the DB, remove all associated users which have the same auth_source with value "ldap #{id}"
  after_destroy :remove_users_with_auth_source

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

  # This method is called after the record is destroyed
  def remove_users_with_auth_source
    User.where(auth_source: "ldap #{id}").find_each do |user|
      user.destroy
    end
  end
end
