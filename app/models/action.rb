# frozen_string_literal: true

# The action that should be permitted.
# Used to define role-based permission in a database.
class Action < ApplicationRecord
  has_many :permissions, dependent: :destroy, inverse_of: :action
end
