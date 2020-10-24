# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'User valid' do
    eric = users(:user_eric)
    assert eric.valid?
  end
end
