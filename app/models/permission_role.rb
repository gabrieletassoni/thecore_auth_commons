class PermissionRole < ApplicationRecord
  belongs_to :role, inverse_of: :permission_roles
  belongs_to :permission, inverse_of: :permission_roles
end
