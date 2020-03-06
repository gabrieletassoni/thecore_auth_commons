$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "thecore_auth/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "thecore_auth"
  spec.version     = ThecoreAuth::VERSION
  spec.authors     = [""]
  spec.email       = ["gabriele.tassoni@gmail.com"]
  spec.homepage    = "https://github.com/gabrieletassoni/thecore_auth"
  spec.summary     = "Common Auth methods and models to be used in thecore components."
  spec.description = "Provides common User and Role models and Authentication and Authorization via Devise and CanCanCan that can be used or extendend in other engines."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.0.2", ">= 6.0.2.1"

  spec.add_dependency "devise", "~> 4.7"
  spec.add_dependency "cancancan", "~> 3.0"

  spec.add_development_dependency "sqlite3"
end
