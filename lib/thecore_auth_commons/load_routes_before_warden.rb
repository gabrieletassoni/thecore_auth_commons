module ThecoreAuthCommons
  # Loads the application's routes before Warden::Manager sees the request (host Odoo #6329).
  #
  # With config.eager_load off (development, tests outside CI) Rails >= 8.0 draws the routes lazily,
  # inside the router, on the first request. Devise registers Warden's strategies only when the
  # routes load (Devise.configure_warden!), but Warden::Proxy copies the manager's config when the
  # request enters Warden::Manager, before the router: the first request's copy had no strategy, so
  # a sign-in that was the process's first request was refused with the right password.
  #
  # The routes still load on the first request, just one middleware earlier. Once loaded, and with
  # eager_load (production loads them at boot), reload_routes_unless_loaded returns at once. Rails
  # 7.2 draws the routes at boot and has no reload_routes_unless_loaded: nothing to do there.
  class LoadRoutesBeforeWarden
    def initialize(app, application)
      @app = app
      @application = application
    end

    def call(env)
      @application.reload_routes_unless_loaded if @application.respond_to?(:reload_routes_unless_loaded)
      @app.call(env)
    end
  end
end
