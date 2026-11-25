require "test_helper"

# Per-IP limit on failed logins (host Odoo #6052, R6 of host docs/research/admin-access-strong-security.md).
# Only failures count, so users behind one NAT or an integration that signs in often never meet it
# with the right password: after THECORE_LOGIN_FAILURES_PER_MINUTE (20) failed attempts in a minute
# from one IP, every login attempt from that IP answers 429 until the minute is over.
class LoginFailureThrottleTest < ActionDispatch::IntegrationTest
  PASSWORD = "Local-Pass-123!".freeze
  ATTACKER = "203.0.113.5".freeze

  setup do
    @default_store = ThecoreAuthCommons::LoginFailureThrottle.store
    ThecoreAuthCommons::LoginFailureThrottle.store = ActiveSupport::Cache::MemoryStore.new
    User.create!(email: "other@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @user = User.create!(email: "worker@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    travel_to Time.utc(2026, 11, 25, 10, 0, 5)
  end

  teardown do
    travel_back
    ThecoreAuthCommons::LoginFailureThrottle.store = @default_store
  end

  test "the 21st web login in a minute after 20 failures gets 429, even with the right password" do
    20.times do
      web_login "wrong", ip: ATTACKER
      assert_response :unauthorized
    end

    web_login PASSWORD, ip: ATTACKER

    assert_response :too_many_requests
    assert_operator response.headers["Retry-After"].to_i, :>, 0
    assert_not_signed_in
  end

  test "another IP is not limited" do
    20.times { web_login "wrong", ip: ATTACKER }

    web_login PASSWORD, ip: "198.51.100.7"

    assert_redirected_to root_path
  end

  test "the limit is lifted when the minute is over" do
    20.times { web_login "wrong", ip: ATTACKER }

    travel 1.minute
    web_login PASSWORD, ip: ATTACKER

    assert_redirected_to root_path
  end

  test "successful logins never count" do
    25.times do
      web_login PASSWORD, ip: ATTACKER
      assert_redirected_to root_path
      reset!
    end
  end

  test "failures on the API login count toward the same limit and get 429 as JSON" do
    10.times { web_login "wrong", ip: ATTACKER }
    10.times do
      api_login "wrong", ip: ATTACKER
      assert_response :unauthorized
    end

    api_login "Api-Pass-123!", ip: ATTACKER

    assert_response :too_many_requests
    assert_equal "application/json", response.media_type
  end

  test "a forged X-Forwarded-For from an untrusted address does not dodge the limit" do
    20.times { |i| web_login "wrong", ip: ATTACKER, forwarded_for: "192.0.2.#{i + 1}" }

    web_login PASSWORD, ip: ATTACKER, forwarded_for: "192.0.2.99"

    assert_response :too_many_requests
  end

  test "behind a trusted proxy each client is counted on its own address" do
    20.times { web_login "wrong", ip: "10.0.0.2", forwarded_for: ATTACKER }

    web_login PASSWORD, ip: "10.0.0.2", forwarded_for: "198.51.100.7"
    assert_redirected_to root_path

    reset!
    web_login PASSWORD, ip: "10.0.0.2", forwarded_for: ATTACKER
    assert_response :too_many_requests
  end

  test "other routes, the sign-in form included, are never limited" do
    20.times { web_login "wrong", ip: ATTACKER }

    get new_user_session_path, env: { "REMOTE_ADDR" => ATTACKER }
    assert_response :success
    get root_path, env: { "REMOTE_ADDR" => ATTACKER }
    assert_redirected_to new_user_session_path
  end

  test "the limit is lowered per installation and 0 turns it off" do
    with_env("THECORE_LOGIN_FAILURES_PER_MINUTE" => "3") do
      3.times { web_login "wrong", ip: ATTACKER }
      web_login PASSWORD, ip: ATTACKER
      assert_response :too_many_requests
    end

    with_env("THECORE_LOGIN_FAILURES_PER_MINUTE" => "0") do
      30.times { web_login "wrong", ip: "198.51.100.8" }
      web_login PASSWORD, ip: "198.51.100.8"
      assert_redirected_to root_path
    end
  end

  test "refused OAuth callbacks count, and then the callback gets 429 too" do
    @user.update!(locked: true)
    20.times do
      oauth_callback ip: ATTACKER
      assert_redirected_to new_user_session_path
    end

    @user.update!(locked: false)
    oauth_callback ip: ATTACKER

    assert_response :too_many_requests
  end

  test "in the test environment nothing is counted unless a test sets a store" do
    ThecoreAuthCommons::LoginFailureThrottle.store = nil

    25.times { web_login "wrong", ip: ATTACKER }
    web_login PASSWORD, ip: ATTACKER

    assert_redirected_to root_path
  end

  private

  def oauth_callback(ip:)
    auth = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "123",
                                  info: { email: @user.email, first_name: "Work", last_name: "Er" })
    get "/users/auth/google_oauth2/callback", env: { "REMOTE_ADDR" => ip, "omniauth.auth" => auth }
  end

  def web_login(password, ip:, forwarded_for: nil)
    env = { "REMOTE_ADDR" => ip }
    env["HTTP_X_FORWARDED_FOR"] = forwarded_for if forwarded_for
    post user_session_path, params: { user: { email: @user.email, password: password } }, env: env
  end

  def api_login(password, ip:)
    post "/api/v2/authenticate", params: { auth: { email: @user.email, password: password } },
                                 env: { "REMOTE_ADDR" => ip }, as: :json
  end

  def assert_not_signed_in
    get root_path
    assert_redirected_to new_user_session_path
  end

  def with_env(vars)
    old = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end
