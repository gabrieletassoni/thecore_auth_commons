require 'devise'
require 'cancancan'
require 'kaminari'
require 'activerecord-nulldb-adapter'
require 'abilities/thecore_auth_commons'

require "thecore_auth_commons/engine"

module ThecoreAuthCommons
  # Your code goes here...
end

module Thecore
  class Base
    @@thecore_engines = []
    def self.thecore_engines
      @@thecore_engines
    end
  end
end