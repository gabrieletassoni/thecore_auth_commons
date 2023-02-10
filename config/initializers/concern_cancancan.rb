module ThecoreAuthCommonsCanCanCanConcern
  extend ActiveSupport::Concern

  included do
    def initialize(user)
      # This will always be the first Ability, since the abilities are "last wins"
      self.merge Abilities::ThecoreAuthCommons.new user
      # Other Abilities
      Abilities.constants(false).each do |ability|
        unless ability.to_s == "ThecoreAuthCommons"
          const = Abilities.const_get(ability) 
          self.merge const.new(user) if const.is_a? Class
        end
      end
      # Overrides from the database defined permissions
      ::Permission.joins(roles: :users).where(users: {id: user.id}).order(:id).each do |permission|
        # E.g. can :manage, :all
        self.send(permission.predicate.name.to_sym, permission.action.name.to_sym, (permission.target.name.classify.constantize rescue permission.target.name.to_sym))
      end unless user.blank?
    end
  end
end