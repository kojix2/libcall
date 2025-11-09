# frozen_string_literal: true

require 'test_helper'

class ParserTest < Test::Unit::TestCase
  # Type parsing tests
  test 'parses rust-style integer types' do
    assert_equal :int, Libcall::Parser.parse_type('i32')
    assert_equal :ulong_long, Libcall::Parser.parse_type('u64')
  end

  test 'parses floating point types' do
    assert_equal :double, Libcall::Parser.parse_type('f64')
    assert_equal :float, Libcall::Parser.parse_type('f32')
  end

  test 'parses string types' do
    assert_equal :string, Libcall::Parser.parse_type('cstr')
  end

  test 'parses output pointer types' do
    assert_equal %i[out int], Libcall::Parser.parse_type('out:i32')
  end

  test 'parses array types' do
    assert_equal %i[array int], Libcall::Parser.parse_type('int[]')
  end

  test 'parses output array types' do
    assert_equal [:out_array, :int, 3], Libcall::Parser.parse_type('out:int[3]')
  end

  test 'parses callback type with func keyword' do
    assert_equal :callback, Libcall::Parser.parse_type('func')
  end

  test 'parses callback type with callback keyword' do
    assert_equal :callback, Libcall::Parser.parse_type('callback')
  end

  # Return type parsing tests
  test 'parses return types' do
    assert_equal :int, Libcall::Parser.parse_return_type('i32')
    assert_equal :double, Libcall::Parser.parse_return_type('f64')
    assert_equal :void, Libcall::Parser.parse_return_type('void')
    assert_equal :string, Libcall::Parser.parse_return_type('cstr')
  end

  # Value coercion tests
  test 'coerces floating point values' do
    assert_in_delta 3.14, Libcall::Parser.coerce_value(:double, '3.14'), 0.001
    assert_in_delta 2.5, Libcall::Parser.coerce_value(:float, '2.5'), 0.001
  end

  test 'coerces string values' do
    assert_equal 'hello', Libcall::Parser.coerce_value(:string, '"hello"')
  end

  test 'coerces array values' do
    assert_equal [1, 2, 3], Libcall::Parser.coerce_value(%i[array int], '1,2,3')
  end

  test 'coerces callback spec with func keyword' do
    spec = Libcall::Parser.coerce_value(:callback, "'int(int a,int b){a+b}'")
    assert_equal :callback, spec[:kind]
    assert_equal :int, spec[:ret]
    assert_equal %i[int int], spec[:args]
    assert_equal '{|a,b| a+b}', spec[:block]
  end

  test 'coerces callback spec with callback keyword' do
    spec = Libcall::Parser.coerce_value(:callback, "'int(int a,int b){a-b}'")
    assert_equal :callback, spec[:kind]
    assert_equal :int, spec[:ret]
    assert_equal %i[int int], spec[:args]
    assert_equal '{|a,b| a-b}', spec[:block]
  end
end
