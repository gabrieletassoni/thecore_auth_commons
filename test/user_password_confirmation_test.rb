require "test_helper"

# User#check_password_and_confirmation_equal is a validation callback: lifecycle, not API, so
# private and out of model_driven_api's a[methods] reach (host Odoo #6314). It still validates.
class UserPasswordConfirmationTest < ActiveSupport::TestCase
  PASSWORD = "Local-Pass-123!".freeze

  test "the callback is private" do
    assert User.private_method_defined?(:check_password_and_confirmation_equal)
    refute User.public_method_defined?(:check_password_and_confirmation_equal)
  end

  test "a password that differs from its confirmation is invalid" do
    user = User.new(email: "mismatch@example.com", password: PASSWORD, password_confirmation: "#{PASSWORD}x")

    refute user.valid?
    assert user.errors.added?(:password, I18n.t("validation.errors.password_and_confirm_must_be_the_same"))
  end

  test "a password equal to its confirmation passes this check" do
    user = User.new(email: "match@example.com", password: PASSWORD, password_confirmation: PASSWORD)

    assert user.valid?, user.errors.full_messages.to_sentence
  end
end
