class RoleUser < ApplicationRecord
  belongs_to :user, inverse_of: :role_users
  belongs_to :role, inverse_of: :role_users
end
