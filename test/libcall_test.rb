# frozen_string_literal: true

require 'test_helper'

class LibcallTest < Test::Unit::TestCase
  test 'VERSION' do
    assert do
      ::Libcall.const_defined?(:VERSION)
    end
  end

  test 'parser parses rust-style integers' do
    assert_equal :int, Libcall::Parser.parse_type('i32')
    assert_equal :ulong_long, Libcall::Parser.parse_type('u64')
  end

  test 'parser parses floats' do
    assert_equal :double, Libcall::Parser.parse_type('f64')
    assert_in_delta 3.14, Libcall::Parser.coerce_value(:double, '3.14'), 0.001
    assert_equal :float, Libcall::Parser.parse_type('f32')
    assert_in_delta 2.5, Libcall::Parser.coerce_value(:float, '2.5'), 0.001
  end

  test 'parser parses strings' do
    assert_equal :string, Libcall::Parser.parse_type('cstr')
    assert_equal 'hello', Libcall::Parser.coerce_value(:string, '"hello"')
  end

  test 'parser parses return type' do
    assert_equal :int, Libcall::Parser.parse_return_type('i32')
    assert_equal :double, Libcall::Parser.parse_return_type('f64')
    assert_equal :void, Libcall::Parser.parse_return_type('void')
    assert_equal :string, Libcall::Parser.parse_return_type('cstr')
  end

  test 'parser parses out:TYPE to output pointer' do
    assert_equal %i[out int], Libcall::Parser.parse_type('out:i32')
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(%i[out int])
  end

  test 'fiddle type conversion' do
    assert_equal Fiddle::TYPE_INT, Libcall::TypeMap.to_fiddle_type(:int)
    assert_equal Fiddle::TYPE_DOUBLE, Libcall::TypeMap.to_fiddle_type(:double)
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(:string)
  end

  test 'parser and types for arrays' do
    assert_equal %i[array int], Libcall::Parser.parse_type('int[]')
    assert_equal [:out_array, :int, 3], Libcall::Parser.parse_type('out:int[3]')
    assert_equal [1, 2, 3], Libcall::Parser.coerce_value(%i[array int], '1,2,3')
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(%i[array int])
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type([:out_array, :int, 3])
  end

  test 'parser parses callback func spec' do
    assert_equal :callback, Libcall::Parser.parse_type('func')
    spec = Libcall::Parser.coerce_value(:callback, "'int(int,int){|a,b| a+b}'")
    assert_equal({ kind: :callback, ret: :int, args: %i[int int], block: '{|a,b| a+b}' }, spec)
  end

  test "parser accepts 'callback' keyword alias" do
    assert_equal :callback, Libcall::Parser.parse_type('callback')
    spec = Libcall::Parser.coerce_value(:callback, "'int(int,int){|a,b| a-b}'")
    assert_equal({ kind: :callback, ret: :int, args: %i[int int], block: '{|a,b| a-b}' }, spec)
  end
end
