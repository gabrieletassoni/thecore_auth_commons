# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def test_should_not_be_possible_to_create_an_empty_user
    u = User.new
    assert(!u.save)
    assert(u.errors.include?(:email))
    assert(u.errors.include?(:password))
  end

  def test_should_generate_a_valid_uuid_as_access_token
    u = User.new

    # access_token is generated before validation
    assert(u.access_token.blank?)
    u.valid?
    assert(!u.access_token.blank?)

    uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    assert(uuid_regex.match?(u.access_token))
  end
end
