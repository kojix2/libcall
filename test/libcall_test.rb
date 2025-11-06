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
    assert_equal Fiddle::TYPE_VOIDP, Libcall::Parser.fiddle_type(%i[out int])
  end

  test 'fiddle type conversion' do
    assert_equal Fiddle::TYPE_INT, Libcall::Parser.fiddle_type(:int)
    assert_equal Fiddle::TYPE_DOUBLE, Libcall::Parser.fiddle_type(:double)
    assert_equal Fiddle::TYPE_VOIDP, Libcall::Parser.fiddle_type(:string)
  end
end
