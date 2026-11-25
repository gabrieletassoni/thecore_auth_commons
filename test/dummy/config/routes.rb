Rails.application.routes.draw do
  # Devise web login as the host apps mount it (thecore_ui_commons), so integration tests can sign in.
  devise_for :users, controllers: { sessions: "users/sessions" }
  # The OAuth callbacks need a configured provider to be routed by devise_for: tests reach the
  # callback directly, with request.env["omniauth.auth"] set as OmniAuth would.
  devise_scope :user do
    get "test_oauth/google", to: "users/omniauth_callbacks#google"
    # The real callback path, where LoginFailureThrottle looks for OAuth failures.
    get "users/auth/google_oauth2/callback", to: "users/omniauth_callbacks#google"
  end

  # model_driven_api's login route, faked (see FakeApiAuthenticationController).
  post "api/v2/authenticate", to: "fake_api_authentication#authenticate"

  root "protected#show"
end
