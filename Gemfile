source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in thecore_auth_commons.gemspec.
gemspec

# The Rails line this suite is tested on, the host apps' one (Odoo #6088): Rails 7.2.4, which
# runs on json 3 (the old `json < 3.0` pin held Rails back at 7.2.3.x), and minitest 5 (Rails 7.2's
# test runner breaks on minitest 6). Without these pins a fresh CI resolution drifts: one run
# picked Rails 8.1, others Rails 7.2.3 with minitest 6. Odoo #6089 turns this into a 7.2/8.1 matrix.
gem "railties", "~> 7.2.4" # pins the whole Rails line without adding frameworks the dummy app lacks
gem "minitest", "~> 5.25"

gem "pg", "~> 1.1"

# Authentication
# https://github.com/heartcombo/devise
gem 'devise', '>= 5.0.4', '< 6'
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

# JUnit XML report in CI (test/support/junit_report.rb, only when JUNIT_REPORT_DIR is set).
gem "minitest-reporters", "~> 1.8"
