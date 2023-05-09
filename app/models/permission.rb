# frozen_string_literal: true

# Defines an approvval for access or using a resource.
# This can be assigned to one or more Roles.
# Used to define role-based permission in a database.
class Permission < ApplicationRecord
  # REFERENCES
  has_many :permission_roles, dependent: :destroy, inverse_of: :permission
  has_many :roles, through: :permission_roles, inverse_of: :permissions
  belongs_to :predicate, inverse_of: :permissions
  belongs_to :action, inverse_of: :permissions
  belongs_to :target, inverse_of: :permissions

  # VALIDATIONS
  validates :predicate_id, presence: true, uniqueness: { scope: %i[action_id target_id] }
  validates :action_id, presence: true
  validates :target_id, presence: true

  def display_name
    p = begin
      I18n.t "permissions.predicates.#{predicate.name}", default: predicate.name.titleize
    rescue StandardError
      nil
    end
    a = begin
      I18n.t "permissions.actions.#{action.name}", default: action.name.titleize
    rescue StandardError
      nil
    end
    m = begin
      I18n.t "activerecord.models.#{target.name}", default: target.name.titleize
    rescue StandardError
      nil
    end
    [p, a, m].join(' ')
  end
end
