Rails.application.routes.draw do
  # Devise web login as the host apps mount it (thecore_ui_commons), so integration tests can sign in.
  devise_for :users, controllers: { sessions: "users/sessions" }
  # The OAuth callbacks need a configured provider to be routed by devise_for: tests reach the
  # callback directly, with request.env["omniauth.auth"] set as OmniAuth would.
  devise_scope :user do
    get "test_oauth/google", to: "users/omniauth_callbacks#google"
  end

  root "protected#show"
end
