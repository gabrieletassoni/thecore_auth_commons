module ThecoreAuthCommonsUserConcern
  extend ActiveSupport::Concern

  included do
    # REFERENCES
    has_many :role_users, dependent: :destroy, inverse_of: :user
    has_many :roles, through: :role_users, inverse_of: :users
    # VALIDATIONS
    validates :email, uniqueness: { case_sensitive: false }, presence: true, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
    validates :password, presence: true, on: :create
    validates :password_confirmation, presence: true, on: :create
    validate :check_password_and_confirmation_equal
    validates :access_token, uniqueness: true
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
end