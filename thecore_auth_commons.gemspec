$:.push File.expand_path("lib", __dir__)

require_relative "lib/thecore_auth_commons/version"

Gem::Specification.new do |spec|
  spec.name        = "thecore_auth_commons"
  spec.version     = ThecoreAuthCommons::VERSION
  spec.authors     = ["Gabriele Tassoni"]
  spec.email       = ["g.tassoni@bancolini.com"]
  spec.homepage    = "https://github.com/gabrieletassoni/thecore_auth_commons"
  spec.summary     = "Common Auth methods and models to be used in thecore components."
  spec.description = "Provides common User and Role models to attach Authentication and Authorization via your preferred gem."
  
  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gabrieletassoni/thecore_auth_commons"
  spec.metadata["changelog_uri"] = "https://github.com/gabrieletassoni/thecore_auth_commons/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  # Authentication
  # https://github.com/heartcombo/devise
  spec.add_dependency 'devise', '~> 4.8'
  # Authorization
  # https://github.com/CanCanCommunity/cancancan
  spec.add_dependency 'cancancan', '~> 3.4'
  # Pagination
  # https://github.com/kaminari/kaminari
  spec.add_dependency 'kaminari', "~> 1.2"

  # https://github.com/nulldb/nulldb
  spec.add_dependency 'activerecord-nulldb-adapter', '~> 1.0'
  
  spec.add_dependency "thecore_settings", "~> 3.0"

  # Testing
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "database_cleaner", "~> 2.0"
  spec.add_development_dependency "factory_bot", "~> 6.2"
  spec.add_development_dependency "rubocop", "~> 1.45"
  spec.add_development_dependency "rubocop-rspec", "~> 2.18"
  spec.add_development_dependency "sqlite3", "~> 1.4"
end
