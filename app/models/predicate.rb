# frozen_string_literal: true

class Predicate < ApplicationRecord
  has_many :permissions, dependent: :destroy, inverse_of: :predicate
end
