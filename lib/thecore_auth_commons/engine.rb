module ThecoreAuthCommons
  class Engine < ::Rails::Engine
    # Right after RemoteIp, so the throttle sees the client's address as Rails resolves it
    # (X-Forwarded-For only from trusted proxies), and wraps every login route (host Odoo #6052).
    initializer "thecore_auth_commons.login_failure_throttle" do |app|
      app.middleware.insert_after ActionDispatch::RemoteIp, ThecoreAuthCommons::LoginFailureThrottle
    end
  end
end
