$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "thecore_auth_commons/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "thecore_auth_commons"
  spec.version     = ThecoreAuthCommons::VERSION
  spec.authors     = ["Gabriele Tassoni"]
  spec.email       = ["gabriele.tassoni@gmail.com"]
  spec.homepage    = "https://github.com/gabrieletassoni/thecore_auth_commons"
  spec.summary     = "Common Auth methods and models to be used in thecore components."
  spec.description = "Provides common User and Role models to attach Authentication and Authorization via your preferred gem."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.0"
  # Authentication
  # https://github.com/heartcombo/devise
  spec.add_dependency 'devise', '~> 4.7'
  # Authorization
  # https://github.com/CanCanCommunity/cancancan
  spec.add_dependency 'cancancan', '~> 3.1'
  # Pagination
  # https://github.com/amatsuda/kaminari
  spec.add_dependency 'kaminari', "~> 1.1"

  spec.add_development_dependency "sqlite3", "~> 1.4"
end
