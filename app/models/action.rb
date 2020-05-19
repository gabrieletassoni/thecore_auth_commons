class Action < ApplicationRecord
    has_many :permissions, dependent: :destroy, inverse_of: :action
end