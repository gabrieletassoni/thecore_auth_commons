# frozen_string_literal: true
require 'abilities/thecore_auth_commons'

class Ability
  include CanCan::Ability

  def initialize(user)
    # This will always be the first Ability, since the abilities are "last wins"
    self.merge Abilities::ThecoreAuthCommons.new user
    # Other Abilities
    Abilities.constants(false).each do |ability|
      unless ability == "ThecoreAuthCommons"
        const = Abilities.const_get(ability) 
        self.merge const.new(user) if const.is_a? Class
      end
    end
  end
end
