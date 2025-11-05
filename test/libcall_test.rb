# frozen_string_literal: true

require 'test_helper'

class LibcallTest < Test::Unit::TestCase
  test 'VERSION' do
    assert do
      ::Libcall.const_defined?(:VERSION)
    end
  end

  test 'parser parses rust-style integers' do
    type, value = Libcall::Parser.parse_arg('42i32')
    assert_equal :int, type
    assert_equal 42, value

    type, value = Libcall::Parser.parse_arg('100u64')
    assert_equal :ulong_long, type
    assert_equal 100, value
  end

  test 'parser parses floats' do
    type, value = Libcall::Parser.parse_arg('3.14f64')
    assert_equal :double, type
    assert_in_delta 3.14, value, 0.001

    type, value = Libcall::Parser.parse_arg('2.5f32')
    assert_equal :float, type
    assert_in_delta 2.5, value, 0.001
  end

  test 'parser parses strings' do
    type, value = Libcall::Parser.parse_arg('"hello"')
    assert_equal :string, type
    assert_equal 'hello', value
  end

  test 'parser parses return type' do
    assert_equal :int, Libcall::Parser.parse_return_type('i32')
    assert_equal :double, Libcall::Parser.parse_return_type('f64')
    assert_equal :void, Libcall::Parser.parse_return_type('void')
    assert_equal :string, Libcall::Parser.parse_return_type('cstr')
  end

  test 'fiddle type conversion' do
    assert_equal Fiddle::TYPE_INT, Libcall::Parser.fiddle_type(:int)
    assert_equal Fiddle::TYPE_DOUBLE, Libcall::Parser.fiddle_type(:double)
    assert_equal Fiddle::TYPE_VOIDP, Libcall::Parser.fiddle_type(:string)
  end
end
