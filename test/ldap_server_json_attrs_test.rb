require "test_helper"

# thecore_auth_commons is the lowest Thecore layer: it must not call into model_driven_api
# (which sits above it and is not one of its dependencies). Api::LdapServer used to call
# ::ModelDrivenApi.smart_merge(json_attrs || {}, {}) — a no-op merge that crashed with
# NameError in any app without model_driven_api as soon as LdapServer was loaded. Likewise
# RailsAdmin::LdapServer called `rails_admin` unconditionally (rails_admin is not a dependency).
class LdapServerJsonAttrsTest < ActiveSupport::TestCase
  test "LdapServer loads and exposes json_attrs without model_driven_api or rails_admin" do
    refute defined?(::ModelDrivenApi), "precondition: model_driven_api is not in this gem's bundle"
    refute defined?(::RailsAdmin::Config), "precondition: rails_admin is not in this gem's bundle"
    assert_kind_of Hash, LdapServer.json_attrs
  end
end
