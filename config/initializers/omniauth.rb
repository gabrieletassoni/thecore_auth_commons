include Devise::OmniAuth::UrlHelpers if defined?(Devise::OmniAuth::UrlHelpers)

Rails.application.config.middleware.use OmniAuth::Builder do
  provider(
    :entra_id,
    {
      client_id: ENV['ENTRA_CLIENT_ID'],
      client_secret: ENV['ENTRA_CLIENT_SECRET'],
      tenant_id: ENV['ENTRA_TENANT_ID'], # Needed for Microsoft
      scope: 'openid profile email User.Read',
      response_type: 'code',
      name: "microsoft"
    }
  ) if ThecoreAuthCommons.entra_id_vars?
  provider(
    :google_oauth2, 
    ENV['GOOGLE_CLIENT_ID'], 
    ENV['GOOGLE_CLIENT_SECRET'], 
    {
      scope: 'email,profile',
      prompt: 'select_account',
      access_type: 'online',
      name: "google"
    }
  ) if ThecoreAuthCommons.google_oauth2_vars?
end

OmniAuth.config.allowed_request_methods = [:get, :post]
OmniAuth.config.silence_get_warning = true