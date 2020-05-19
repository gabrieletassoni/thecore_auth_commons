class Target < ApplicationRecord
    has_many :permissions, dependent: :destroy, inverse_of: :target
end