module Abilities
    class ThecoreAuthCommons
        include CanCan::Ability
        def initialize user
            # Main abilities file for Thecore applications
            if user.present?
                # Users' abilities
                # -
                if user.admin?
                    # Admins' abiities
                    can :manage, :all # only allow admin users to access Rails Admin
                    # prevents killing himself
                    cannot :destroy, ::User do |u| 
                        u.id == user.id
                    end
                end
            end
        end
    end
end
