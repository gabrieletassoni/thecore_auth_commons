# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities

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
