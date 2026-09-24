require "test_helper"

# The lowest Thecore layer must load on its own: eager loading every file of the engine must not
# hit constants from gems above it (model_driven_api's NonCrudEndpoints / ModelDrivenApi,
# rails_admin). A scaffolded, empty `Endpoints::LdapServer < NonCrudEndpoints` did exactly that
# — invisible with lazy autoloading, a NameError at boot with eager loading (production).
class EagerLoadTest < ActiveSupport::TestCase
  test "the engine eager-loads without model_driven_api" do
    refute defined?(::NonCrudEndpoints), "precondition: model_driven_api is not in this gem's bundle"
    engine_app = File.expand_path("../app", __dir__)
    roots = Rails.autoloaders.main.dirs.select { |dir| dir.start_with?(engine_app) }
    refute_empty roots, "precondition: the engine's app/ subdirectories are autoload roots"
    roots.each { |dir| Rails.autoloaders.main.eager_load_dir(dir) }
  end
end
