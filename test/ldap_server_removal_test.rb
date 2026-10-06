require "test_helper"

# Removing an LdapServer must leave the users it imported exactly as they were — same
# record, same roles — only their auth_source changes, to local.
class LdapServerRemovalTest < ActiveSupport::TestCase
  setup do
    @server = LdapServer.create!(host: "ldap.example.com", base_dn: "dc=example,dc=com")
    @role = Role.create!(name: "ldap_removal_role")
    @user = User.create!(email: "ldap_removal@example.com", auth_source: "ldap #{@server.id}",
                         password: "Abcdef1!", password_confirmation: "Abcdef1!")
    @user.roles << @role
  end

  test "a user whose LDAP server is removed is kept, roles included, as a local user" do
    @server.destroy!

    @user.reload
    assert_equal [@role], @user.roles.to_a
    assert_equal "local", @user.auth_source
  end

  test "users of other LDAP servers are left alone" do
    other = LdapServer.create!(host: "other.example.com", base_dn: "dc=other,dc=com")
    @user.update_columns(auth_source: "ldap #{other.id}")

    @server.destroy!

    assert_equal "ldap #{other.id}", @user.reload.auth_source
  end
end
