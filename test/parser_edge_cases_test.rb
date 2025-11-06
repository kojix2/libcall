# frozen_string_literal: true

require 'test_helper'

class ParserEdgeCasesTest < Test::Unit::TestCase
  test 'string coercion with and without quotes' do
    assert_equal 'hello world', Libcall::Parser.coerce_value(:string, '"hello world"')
    assert_equal 'hello', Libcall::Parser.coerce_value(:string, 'hello')
  end

  test 'negative integers and floats' do
    assert_equal(-42, Libcall::Parser.coerce_value(:int, '-42'))
    assert_in_delta(-3.14, Libcall::Parser.coerce_value(:double, '-3.14'), 0.001)
  end

  test 'unsigned integers' do
    assert_equal 0, Libcall::Parser.coerce_value(:uint, '0')
    assert_kind_of Integer, Libcall::Parser.coerce_value(:ulong_long, '18446744073709551615')
  end

  test 'void cannot be used as argument' do
    assert_raise(Libcall::Error) do
      Libcall::Parser.coerce_value(:void, '0')
    end
  end

  test 'return type parsing' do
    assert_equal :void, Libcall::Parser.parse_return_type('void')
    assert_equal :void, Libcall::Parser.parse_return_type(nil)
    assert_equal :void, Libcall::Parser.parse_return_type('')
  end
end
