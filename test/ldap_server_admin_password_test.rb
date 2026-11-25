require "test_helper"

# ldap_servers.admin_password is write-only (host ADR 0046 point 10, host Odoo #6084): the LDAP
# authenticator and test_connection still read it, but no serialization returns it, it cannot be
# searched or sorted on, and it carries no index.
class LdapServerAdminPasswordTest < ActiveSupport::TestCase
  setup do
    @server = LdapServer.create!(host: "ldap.example.com", base_dn: "dc=example,dc=com",
                                 admin_user: "cn=admin", admin_password: "Ldap-S3cret")
  end

  test "no serialization contains the admin password, whatever the options" do
    [@server.to_json,
     @server.to_json(only: [:host, :admin_password]),
     @server.to_json(methods: [:admin_password, :attributes, :attributes_before_type_cast]),
     { "server" => @server }.to_json,
     LdapServer.all.to_json(only: [:admin_password])].each do |json|
      refute_includes json, "Ldap-S3cret"
    end
    assert_equal "ldap.example.com", @server.as_json["host"]
    assert_equal "Ldap-S3cret", @server.reload.admin_password
  end

  test "the admin password is declared write-only for the serializers that read columns" do
    assert_equal %w[admin_password], LdapServer.write_only_attributes
  end

  test "the admin password is not searchable" do
    refute_includes LdapServer.ransackable_attributes, "admin_password"
    assert_includes LdapServer.ransackable_attributes, "host"
  end

  test "the admin password has no index" do
    refute ActiveRecord::Base.connection.index_exists?(:ldap_servers, :admin_password)
  end
end
