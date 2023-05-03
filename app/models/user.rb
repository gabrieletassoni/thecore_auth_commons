# frozen_string_literal: true

# A subject that should be authenticated/authorized.
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable
  devise :trackable
  devise :validatable
  # TODO: If it works, these must be added to another gem one which deal
  # more with sessions
  # devise :database_authenticatable
  # devise :rememberable
  # devise :trackable
  # devise :validatable
  # devise :timeoutable, timeout_in: 30.minutes

  before_validation on: :create do
    # If the generated uuid is not already present, then create the user with the proposed uuid
    # Otherwise, try to generate another one
    begin
      self.access_token = SecureRandom.uuid # urlsafe_base64(32)
    end while ::User.exists?(access_token: access_token)
  end
  # REFERENCES
  has_many :role_users, dependent: :destroy, inverse_of: :user
  has_many :roles, through: :role_users, inverse_of: :users
  # VALIDATIONS
  validates :email, uniqueness: { case_sensitive: false }, presence: true,
                    format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
  validates :password, presence: true, on: :create
  validates :password_confirmation, presence: true, on: :create
  validate :check_password_and_confirmation_equal
  validates :access_token, uniqueness: true
  validates_each :admin do |record, attr, _value|
    # Don't want admin == false if the current user is the only admin
    if record.admin_changed? && record.admin_was == true && User.where(admin: true).count == 1
      record.errors.add(attr,
                        I18n.t('validation.errors.cannot_unadmin_last_admin'))
    end
  end
  validates_each :locked do |record, attr, _value|
    # Don't want locked == true if the current user is the only admin
    if record.locked_changed? && record.locked_was == false && User.where(locked: false).count == 1
      record.errors.add(attr,
                        I18n.t('validation.errors.cannot_lock_last_admin'))
    end
  end

  def display_name
    email
  end

  def has_role?(role)
    roles.include? role.to_s
  end

  def authenticate(password)
    self&.valid_password?(password) ? self : nil
  end

  protected

  def check_password_and_confirmation_equal
    return if password == password_confirmation

    errors.add(:password,
               I18n.t('validation.errors.password_and_confirm_must_be_the_same'))
  end
end
