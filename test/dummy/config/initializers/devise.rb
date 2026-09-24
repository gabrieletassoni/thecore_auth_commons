# frozen_string_literal: true

# thecore_auth_commons's app/models/user.rb calls `devise ...` in its class body, which only
# exists once Devise's ActiveRecord ORM adapter has extended ActiveRecord::Base with
# Devise::Models. A real host app gets this from its generated config/initializers/devise.rb;
# this dummy app had none, so boot crashed with `undefined method 'devise' for class User`
# (User is first loaded by thecore_backend_commons's after_initialize hook). Minimal version of
# mytask's own test/dummy/config/initializers/devise.rb.
Devise.setup do |config|
  config.mailer_sender = 'test@example.com'
  require 'devise/orm/active_record'
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 8..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.sign_out_via = :delete
end
