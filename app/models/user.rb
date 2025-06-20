class User < ApplicationRecord
  # Get the minimum password length from the Environemnt or set it to 8
  devise :database_authenticatable, 
    :rememberable, 
    :trackable, 
    :timeoutable,
    :omniauthable,
    :validatable,
    # Devise modules configurations:
    # Omniauthable allows the user to sign in with external providers
    :omniauth_providers => [:google_oauth2, :entra_id],
    # Validatable allows the user to validate their email and password
    :password_length => ENV.fetch('MIN_PASSWORD_LENGTH', 8).to_i..128,
    :timeout_in => ENV.fetch('SESSION_TIMEOUT_IN_MINUTES', 31).to_i.minutes


  # REFERENCES
  has_many :role_users, dependent: :destroy, inverse_of: :user
  has_many :roles, through: :role_users, inverse_of: :users
  # VALIDATIONS
  validates :email, uniqueness: { case_sensitive: false }, presence: true, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
  validates :password, presence: true, on: :create
  validates :password_confirmation, presence: true, on: :create
  validate :check_password_and_confirmation_equal
  validates_each :password do |record, attr, value|
    # Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character or be blank
    record.errors.add(attr, I18n.t("validation.errors.password_must_contain_uppercase_lowercase_number_special_character")) unless value.blank? || (value =~ /[A-Z]/ && value =~ /[a-z]/ && value =~ /[0-9]/ && value =~ /[^A-Za-z0-9]/)
  end
  validates_each :admin do |record, attr, value|
    # Don't want admin == false if the current user is the only admin
    record.errors.add(attr, I18n.t("validation.errors.cannot_unadmin_last_admin")) if record.admin_changed? && record.admin_was == true && User.where(admin: true).count == 1
  end
  validates_each :locked do |record, attr, value|
    # Don't want locked == true if the current user is the only admin
    record.errors.add(attr, I18n.t("validation.errors.cannot_lock_last_admin")) if record.locked_changed? && record.locked_was == false && User.where(locked: false).count == 1
  end
  
  def display_name
    email
  end
  
  def has_role? role
    roles.include? role.to_s
  end
  
  def authenticate password
    self&.valid_password?(password) ? self : nil
  end
  
  def check_password_and_confirmation_equal
    errors.add(:password, I18n.t("validation.errors.password_and_confirm_must_be_the_same")) unless password == password_confirmation
  end
end
