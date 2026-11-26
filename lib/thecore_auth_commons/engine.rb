module ThecoreAuthCommons
  class Engine < ::Rails::Engine
    # Right after RemoteIp, so the throttle sees the client's address as Rails resolves it
    # (X-Forwarded-For only from trusted proxies), and wraps every login route (host Odoo #6052).
    initializer "thecore_auth_commons.login_failure_throttle" do |app|
      app.middleware.insert_after ActionDispatch::RemoteIp, ThecoreAuthCommons::LoginFailureThrottle
    end

    # Right before Devise's Warden::Manager: the first request's Warden must see the strategies
    # Devise registers when the lazily drawn routes load (host Odoo #6329).
    initializer "thecore_auth_commons.load_routes_before_warden" do |app|
      app.middleware.insert_before Warden::Manager, ThecoreAuthCommons::LoadRoutesBeforeWarden, app
    end
  end
end
