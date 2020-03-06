class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :timeoutable

  # Devise: login with username or password
  attr_writer :login
  def login
    @login || self.username || self.email
  end
  def self.find_first_by_auth_conditions(warden_conditions)
    login = warden_conditions.dup.delete(:login)
    where(username: login).or(User.where(email: login)).first
  end
  # Devise END
  # REFERENCES
  has_many :role_users, dependent: :destroy, inverse_of: :user
  has_many :roles, through: :role_users, inverse_of: :users
  # VALIDATIONS
  validates :username, uniqueness: { case_sensitive: false }, format: { with: /\A[a-zA-Z0-9]*\z/, on: :create}, length: { in: 4..15 }, presence: true
  validates :email, uniqueness: { case_sensitive: false }, presence: true, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
  validates :password, presence: true, on: :create
  validates :password_confirmation, presence: true, on: :create
  validate :check_password_and_confirmation_equal
  validates_each :admin do |record, attr, value|
    # Don't want admin == false if the current user is the only admin
    record.errors.add(attr, I18n.t("validation.errors.cannot_unadmin_latest_admin")) if record.admin_changed? && record.admin_was == true && User.where(admin: true).count == 1
  end

  def display_name
    username
  end

  def has_role? role
    roles.include? role
  end

  protected

  def check_password_and_confirmation_equal
    errors.add(:password, I18n.t("validation.errors.password_and_confirm_must_be_the_same")) unless password == password_confirmation
  end
end
