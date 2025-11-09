# frozen_string_literal: true

require 'test_helper'

# General smoke tests for the Libcall module
class LibcallTest < Test::Unit::TestCase
  test 'VERSION constant is defined' do
    assert do
      ::Libcall.const_defined?(:VERSION)
    end
  end

  test 'VERSION is a string with semantic versioning format' do
    assert_kind_of String, Libcall::VERSION
    assert_match(/\A\d+\.\d+\.\d+/, Libcall::VERSION)
  end

  test 'Error class is defined' do
    assert do
      ::Libcall.const_defined?(:Error)
    end
  end

  test 'Error inherits from StandardError' do
    assert_equal StandardError, Libcall::Error.superclass
  end
end
