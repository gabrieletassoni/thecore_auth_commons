require "test_helper"

# check_user is what both OAuth callbacks (Devise and model_driven_api) call after login. It used
# to make every OAuth user an admin and to overwrite their password on each login (Odoo #5837).
class CheckUserTest < ActiveSupport::TestCase
  PASSWORD = "Local-Pass-123!".freeze

  test "a new OAuth user is created without admin" do
    user = ThecoreAuthCommons.check_user("new.user@example.com", "New", "User", "google")

    assert user.persisted?
    refute user.admin
    assert_equal "google", user.auth_source
  end

  test "an existing user keeps password, admin flag and auth source" do
    existing = User.create!(email: "local@example.com", password: PASSWORD, password_confirmation: PASSWORD)

    user = ThecoreAuthCommons.check_user("Local@Example.com", "Local", "User", "google")

    assert_equal existing.id, user.id
    existing.reload
    refute existing.admin
    assert existing.valid_password?(PASSWORD), "OAuth login overwrote the local password"
    assert_equal "local", existing.auth_source
  end

  test "an existing admin stays admin" do
    admin = User.create!(email: "boss@example.com", password: PASSWORD, password_confirmation: PASSWORD, admin: true)

    ThecoreAuthCommons.check_user(admin.email, "Boss", "User", "microsoft")

    assert admin.reload.admin
    assert admin.valid_password?(PASSWORD)
  end

  test "a blank email gives no user" do
    assert_nil ThecoreAuthCommons.check_user(nil, "No", "Mail", "google")
    assert_nil ThecoreAuthCommons.check_user("", "No", "Mail", "google")
  end
end
