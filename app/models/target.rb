# frozen_string_literal: true

# The resource that should be approved.
class Target < ApplicationRecord
  has_many :permissions, dependent: :destroy, inverse_of: :target
end
