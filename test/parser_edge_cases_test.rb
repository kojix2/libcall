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

  test 'pointer null coercion' do
    assert_equal 0, Libcall::Parser.coerce_value(:voidp, 'null')
    assert_equal 0, Libcall::Parser.coerce_value(:voidp, 'NULL')
    assert_equal 0, Libcall::Parser.coerce_value(:voidp, 'nil')
    assert_equal 0, Libcall::Parser.coerce_value(:voidp, '0')
  end

  test 'callback with named params injects block args when omitted' do
    token = 'int(void* a, void* b){ a <=> b }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal :callback, cb[:kind]
    assert_equal :int, cb[:ret]
    assert_equal %i[voidp voidp], cb[:args]
    assert_match(/\{\|a,b\|/, cb[:block])
  end

  test 'callback with explicit block params is not modified' do
    token = 'int(void* a, void* b){|x,y| x }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal :int, cb[:ret]
    assert_equal %i[voidp voidp], cb[:args]
    assert_match(/\{\|x,y\| x \}/, cb[:block])
  end

  test 'callback without names keeps block as-is' do
    token = 'int(void*, void*){ foo }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal %i[voidp voidp], cb[:args]
    # No injection because names are missing
    assert_no_match(/\{\|/, cb[:block])
  end
end
