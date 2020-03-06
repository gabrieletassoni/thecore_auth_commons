module Abilities
    class ThecoreAuth
      include CanCan::Ability
      def initialize user
        if user
            cannot :manage, :all
            if user.admin?
                can :manage, :all # only allow admin users to access everything
                cannot :destroy, User do |u|
                    # prevents suicides
                    u.id == user.id
                end
            end
        end
      end
    end
  end