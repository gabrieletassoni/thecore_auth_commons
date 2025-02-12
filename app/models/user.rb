class User < ApplicationRecord
    # Get the minimum password length from the Environemnt or set it to 8
    devise :database_authenticatable, :rememberable, :trackable, :timeoutable, :validatable, password_length: ENV.fetch('MIN_PASSWORD_LENGTH', 8).to_i..128, timeout_in: ENV.fetch('SESSION_TIMEOUT_IN_MINUTES', 31).to_i.minutes
end
