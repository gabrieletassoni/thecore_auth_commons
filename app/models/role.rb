class Role < ApplicationRecord
    # VALIDATIONS
    validates :name, presence: true, uniqueness: { case_sensitive: false }
    # REFERENCES
    has_many :role_users, dependent: :destroy, inverse_of: :role
    has_many :users, through: :role_users, inverse_of: :roles
    has_many :permission_roles, dependent: :destroy, inverse_of: :role
    has_many :permissions, through: :permission_roles, inverse_of: :roles
    
    def display_name
        (I18n.t name.parameterize.underscore, default: name.titleize rescue nil)
    end
end
