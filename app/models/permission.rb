class Permission < ApplicationRecord
    # REFERENCES
    has_many :permission_roles, dependent: :destroy, inverse_of: :permission
    has_many :roles, through: :permission_roles, inverse_of: :permissions
    belongs_to :predicate, inverse_of: :permissions
    belongs_to :action, inverse_of: :permissions
    belongs_to :target, inverse_of: :permissions

    # VALIDATIONS
    validates :predicate_id, presence: true, uniqueness: {scope: [:action_id, :target_id]}
    validates :action_id, presence: true
    validates :target_id, presence: true

    def display_name
        p = (I18n.t "permissions.predicates.#{predicate.name}", default: predicate.name.titleize rescue nil)
        a = (I18n.t "permissions.actions.#{action.name}", default: action.name.titleize rescue nil)
        m = (I18n.t "activerecord.models.#{target.name}", default: target.name.titleize rescue nil)
        [ p, a, m ].join(" ")
    end
end
