require "test_helper"

# Rails >= 8.0 with eager_load off draws the routes on the first request, inside the router, after
# Warden::Proxy has copied a config with no Devise strategy: the first sign-in was refused with the
# right password (host Odoo #6329). The middleware loads the routes before Warden sees the request.
# The end-to-end proof (a cold sign-in in a fresh process) lives in the host, on Rails 8.1: this
# gem's suite runs on Rails 7.2, which draws the routes at boot.
class LoadRoutesBeforeWardenTest < ActiveSupport::TestCase
  class LazyRoutesApplication
    attr_reader :calls

    def initialize(calls)
      @calls = calls
    end

    def reload_routes_unless_loaded
      calls << :routes
    end
  end

  test "it loads the routes before the next middleware sees the request" do
    calls = []
    downstream = ->(_env) { calls << :warden and [200, {}, ["ok"]] }

    response = ThecoreAuthCommons::LoadRoutesBeforeWarden.new(downstream, LazyRoutesApplication.new(calls)).call({})

    assert_equal [:routes, :warden], calls
    assert_equal [200, {}, ["ok"]], response
  end

  test "on a Rails without lazy routes it only passes the request on" do
    downstream = ->(_env) { [204, {}, []] }

    assert_equal [204, {}, []], ThecoreAuthCommons::LoadRoutesBeforeWarden.new(downstream, Object.new).call({})
  end

  test "it sits right before Devise's Warden::Manager" do
    names = Rails.application.middleware.map(&:name)

    assert_equal "ThecoreAuthCommons::LoadRoutesBeforeWarden", names[names.index("Warden::Manager") - 1]
  end
end
