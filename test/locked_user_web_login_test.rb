require "test_helper"
require "minitest/mock"

# A locked user (users.locked, set from RailsAdmin) must not use the web app through any login
# channel, and an already open session must end at its next request (Odoo #6051). The sign-in
# form refuses them exactly like a wrong password (same status, same words), so it tells neither
# that the account exists nor that the password was right.
class LockedUserWebLoginTest < ActionDispatch::IntegrationTest
  PASSWORD = "Local-Pass-123!".freeze

  setup do
    # The last unlocked user can't be locked (User validation): keep another one around.
    User.create!(email: "other@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @user = User.create!(email: "worker@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    # Devise's lockable key, which hosts and devise-i18n translate as "Your account is locked.":
    # the refusal must never read it.
    I18n.backend.store_translations(:en, devise: { failure: { locked: "Your account is locked." } })
  end

  teardown { I18n.reload! }

  test "an unlocked user signs in with a password" do
    sign_in_with PASSWORD

    get root_path
    assert_response :success
    assert_equal "signed in as worker@example.com", response.body
  end

  test "a wrong password is refused with 401 and the generic message" do
    sign_in_with "Wrong-Pass-123!"

    assert_response :unauthorized
    assert_equal "Invalid credentials or password.", flash[:alert]
  end

  test "a locked user is refused with the right password exactly like a wrong password" do
    @user.update!(locked: true)

    sign_in_with PASSWORD

    assert_response :unauthorized
    assert_equal "Invalid credentials or password.", flash[:alert]
    assert_not_signed_in
  end

  test "a locked user is refused when LDAP authenticates them" do
    @user.update!(locked: true)
    ldap = Struct.new(:user) { def authenticate = user }.new(@user)

    Ldap::Authenticator.stub(:new, ->(**) { ldap }) do
      sign_in_with "the-ldap-password"
    end

    assert_response :unauthorized
    assert_equal "Invalid credentials or password.", flash[:alert]
    assert_not_signed_in
  end

  test "a locked user is refused by the OAuth callback" do
    @user.update!(locked: true)

    get "/test_oauth/google", env: { "omniauth.auth" => oauth_hash(@user.email) }

    assert_redirected_to new_user_session_path
    assert_equal "Invalid credentials or password.", flash[:alert]
    assert_not_signed_in
  end

  test "an unlocked user signs in through the OAuth callback" do
    get "/test_oauth/google", env: { "omniauth.auth" => oauth_hash(@user.email) }

    get root_path
    assert_response :success
  end

  test "a session open before the lock ends at the next request" do
    sign_in_with PASSWORD
    get root_path
    assert_response :success

    @user.reload.update!(locked: true)

    get root_path
    assert_redirected_to new_user_session_path
  end

  private

  def sign_in_with(password)
    post user_session_path, params: { user: { email: @user.email, password: password } }
  end

  def assert_not_signed_in
    get root_path
    assert_redirected_to new_user_session_path
  end

  def oauth_hash(email)
    OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "123",
                           info: { email: email, first_name: "Work", last_name: "Er" })
  end
end
