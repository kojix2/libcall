# frozen_string_literal: true

require 'test_helper'

class ParserEdgeCasesTest < Test::Unit::TestCase
  test 'empty string argument' do
    type, value = Libcall::Parser.parse_arg('""')
    assert_equal :string, type
    assert_equal '', value
  end

  test 'string with quotes inside' do
    type, value = Libcall::Parser.parse_arg('"hello world"')
    assert_equal :string, type
    assert_equal 'hello world', value
  end

  test 'negative integer with type suffix' do
    type, value = Libcall::Parser.parse_arg('-42i32')
    assert_equal :int, type
    assert_equal(-42, value)
  end

  test 'negative float with type suffix' do
    type, value = Libcall::Parser.parse_arg('-3.14f64')
    assert_equal :double, type
    assert_in_delta(-3.14, value, 0.001)
  end

  test 'decimal without leading zero' do
    type, value = Libcall::Parser.parse_arg('.5f64')
    assert_equal :double, type
    assert_in_delta 0.5, value, 0.001
  end

  test 'decimal without trailing digits' do
    type, value = Libcall::Parser.parse_arg('5.f64')
    assert_equal :double, type
    assert_in_delta 5.0, value, 0.001
  end

  test 'zero with type suffix' do
    type, value = Libcall::Parser.parse_arg('0u64')
    assert_equal :ulong_long, type
    assert_equal 0, value
  end

  test 'large unsigned integer' do
    type, value = Libcall::Parser.parse_arg('18446744073709551615u64')
    assert_equal :ulong_long, type
    assert_kind_of Integer, value
  end

  test 'scientific notation fails gracefully' do
    assert_raise(Libcall::Error) do
      Libcall::Parser.parse_arg('1e10f64')
    end
  end

  test 'invalid type suffix' do
    assert_raise(Libcall::Error) do
      Libcall::Parser.parse_arg('42xyz')
    end
  end

  test 'plain integer defaults to int' do
    type, value = Libcall::Parser.parse_arg('42')
    assert_equal :int, type
    assert_equal 42, value
  end

  test 'plain float defaults to double' do
    type, value = Libcall::Parser.parse_arg('3.14')
    assert_equal :double, type
    assert_in_delta 3.14, value, 0.001
  end

  test 'void return type' do
    assert_equal :void, Libcall::Parser.parse_return_type('void')
    assert_equal :void, Libcall::Parser.parse_return_type(nil)
    assert_equal :void, Libcall::Parser.parse_return_type('')
  end

  test 'parse signature with no arguments' do
    ret, args = Libcall::Parser.parse_signature('void()')
    assert_equal :void, ret
    assert_equal [], args
  end

  test 'parse signature with multiple arguments' do
    ret, args = Libcall::Parser.parse_signature('i32(i32,i32,i32)')
    assert_equal :int, ret
    assert_equal %i[int int int], args
  end

  test 'invalid signature format' do
    assert_raise(Libcall::Error) do
      Libcall::Parser.parse_signature('invalid')
    end
  end
end
