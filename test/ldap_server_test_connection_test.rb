require "test_helper"
require "minitest/mock"

# LdapServer#test_connection tells its caller whether the admin bind worked and, when it did not,
# why: it never raises for a server it cannot reach or bind to (thecore_ui_rails_admin#17).
class LdapServerTestConnectionTest < ActiveSupport::TestCase
  setup do
    @server = LdapServer.create!(host: "ldap.example.com", port: 389, base_dn: "dc=example,dc=com",
                                 admin_user: "cn=admin,dc=example,dc=com", admin_password: "secret")
  end

  test "a server without admin credentials fails without contacting it" do
    @server.update!(admin_user: nil, admin_password: nil)

    result = Net::LDAP.stub(:new, ->(*) { flunk "no LDAP connection expected" }) { @server.test_connection }

    assert_not result.success?
    assert_equal "No admin user and password are configured for this server", result.message
  end

  test "a successful admin bind succeeds" do
    result = Net::LDAP.stub(:new, FakeLdap.new(bind: true)) { @server.test_connection }

    assert result.success?
    assert_nil result.message
  end

  test "a refused admin bind fails with the server's reason" do
    result = Net::LDAP.stub(:new, FakeLdap.new(bind: false, reason: "Invalid Credentials")) { @server.test_connection }

    assert_not result.success?
    assert_equal "Invalid Credentials", result.message
  end

  test "an unresolvable host fails with the connection error" do
    unresolvable = FakeLdap.new
    unresolvable.define_singleton_method(:bind) { raise Net::LDAP::Error, "getaddrinfo: Name or service not known" }

    result = Net::LDAP.stub(:new, unresolvable) { @server.test_connection }

    assert_not result.success?
    assert_equal "getaddrinfo: Name or service not known", result.message
  end

  # net-ldap raises the bare Errno for a single host, not a Net::LDAP::Error.
  test "a host refusing the connection fails with the connection error" do
    @server.update!(host: "127.0.0.1", port: 1)

    result = @server.test_connection

    assert_not result.success?
    assert_match(/Connection refused/, result.message)
  end

  # Stands in for Net::LDAP: answers bind, and get_operation_result like net-ldap's OpenStruct.
  FakeLdap = Struct.new(:bind, :reason, keyword_init: true) do
    def get_operation_result = Struct.new(:message).new(reason)
  end
end
