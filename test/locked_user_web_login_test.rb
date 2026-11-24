require "test_helper"
require "minitest/mock"

# A locked user (users.locked, set from RailsAdmin) must not use the web app through any login
# channel, and an already open session must end at its next request (Odoo #6051). The refusal
# reads like a wrong password, so it doesn't tell whether the account exists.
class LockedUserWebLoginTest < ActionDispatch::IntegrationTest
  PASSWORD = "Local-Pass-123!".freeze

  setup do
    # The last unlocked user can't be locked (User validation): keep another one around.
    User.create!(email: "other@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @user = User.create!(email: "worker@example.com", password: PASSWORD, password_confirmation: PASSWORD)
  end

  test "an unlocked user signs in with a password" do
    sign_in_with PASSWORD

    get root_path
    assert_response :success
    assert_equal "signed in as worker@example.com", response.body
  end

  test "a locked user is refused with the right password, with the wrong-password message" do
    sign_in_with "Wrong-Pass-123!"
    wrong_password_alert = flash[:alert]
    @user.update!(locked: true)

    sign_in_with PASSWORD

    assert_redirected_to new_user_session_path
    assert_equal wrong_password_alert, flash[:alert]
    assert_not_signed_in
  end

  test "a locked user is refused when LDAP authenticates them" do
    @user.update!(locked: true)
    ldap = Struct.new(:user) { def authenticate = user }.new(@user)

    Ldap::Authenticator.stub(:new, ->(**) { ldap }) do
      sign_in_with "the-ldap-password"
    end

    assert_redirected_to new_user_session_path
    assert_not_signed_in
  end

  test "a locked user is refused by the OAuth callback" do
    @user.update!(locked: true)

    get "/test_oauth/google", env: { "omniauth.auth" => oauth_hash(@user.email) }

    assert_redirected_to new_user_session_path
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
