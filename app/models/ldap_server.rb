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

  # admin_password is write-only (host ADR 0046 point 10): the authenticator and test_connection
  # read it, nothing serializes it. `methods:` is dropped too, since attributes,
  # attributes_before_type_cast and friends would carry it, and LdapServer serializes no method.
  WRITE_ONLY_ATTRIBUTES = %w[admin_password].freeze

  # model_driven_api >= 3.17.0 leaves these out of v3's JSON:API serializers, which read the
  # columns directly instead of going through serializable_hash.
  def self.write_only_attributes
    WRITE_ONLY_ATTRIBUTES
  end

  def serializable_hash(options = nil)
    options = (options || {}).to_h.symbolize_keys.except(:methods)
    options[:except] = Array(options[:except]) + WRITE_ONLY_ATTRIBUTES.map(&:to_sym)
    options[:only] = Array(options[:only]).map(&:to_s) - WRITE_ONLY_ATTRIBUTES if options[:only]
    super(options).except(*WRITE_ONLY_ATTRIBUTES)
  end

  # Not searchable nor sortable through Ransack (the API's q[...] and s): a filter on it would
  # tell the password character by character.
  def self.ransackable_attributes(auth_object = nil)
    (defined?(super) ? super : column_names) - WRITE_ONLY_ATTRIBUTES
  end

  # The outcome of #test_connection: success? and, when it failed, the reason in message.
  ConnectionResult = Data.define(:success, :message) do
    def success? = success
  end

  # Binds as the admin user and reports whether that worked, and why not. Never raises for a
  # server it cannot reach or bind to: the RailsAdmin test_ldap_server action shows the result.
  # net-ldap raises Net::LDAP::Error for most connection failures, but the bare Errno (a
  # SystemCallError, e.g. ECONNREFUSED) for a single host it cannot connect to.
  def test_connection
    if admin_user.blank? || admin_password.blank?
      return ConnectionResult.new(success: false, message: I18n.t("ldap_server.test_connection.no_admin_credentials"))
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
  rescue Net::LDAP::Error, SystemCallError => e
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
