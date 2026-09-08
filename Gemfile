source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in thecore_auth_commons.gemspec.
gemspec

# json 3.0+ turns the long-tolerated, deprecated `quirks_mode:` option into a hard ArgumentError;
# activesupport (Rails 7.2's JSON encoder) still passes it on every JSON.generate call, so any
# request that commits a session cookie crashes. Same fix as the host app's own Gemfile — pin
# until Rails 8 ships a compatible activesupport release.
gem 'json', '< 3.0'

gem "sqlite3"

# Authentication
# https://github.com/heartcombo/devise
gem 'devise', '~> 4.8'
# Authorization
# https://github.com/CanCanCommunity/cancancan
gem 'cancancan', '~> 3.4'
# Pagination
# https://github.com/kaminari/kaminari
gem 'kaminari', "~> 1.2"

# https://github.com/nulldb/nulldb
gem 'activerecord-nulldb-adapter', '~> 1.0'
# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
