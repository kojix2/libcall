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

  test 'callback with explicit block params is rejected now' do
    token = 'int(void* a, void* b){|x,y| x }'
    assert_raise(Libcall::Error) do
      Libcall::Parser.coerce_value(:callback, token)
    end
  end

  test 'callback without names cannot inject params (remains anonymous block)' do
    token = 'int(void*, void*){ foo }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal %i[voidp voidp], cb[:args]
    assert_no_match(/\{\|/, cb[:block])
  end

  test 'callback with partial naming: first arg named, second unnamed does not inject' do
    token = 'int(int a, int){ a + 1 }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal %i[int int], cb[:args]
    # names_with_nils = ['a', nil] so not all are truthy; no injection
    assert_no_match(/\{\|/, cb[:block])
    assert_equal '{ a + 1 }', cb[:block]
  end

  test 'callback with partial naming: first arg unnamed, second named does not inject' do
    token = 'int(int, int b){ b * 2 }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal %i[int int], cb[:args]
    # names_with_nils = [nil, 'b'] so not all are truthy; no injection
    assert_no_match(/\{\|/, cb[:block])
    assert_equal '{ b * 2 }', cb[:block]
  end

  test 'callback with partial naming: middle arg unnamed does not inject' do
    token = 'int(int a, int, int c){ a + c }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal %i[int int int], cb[:args]
    # names_with_nils = ['a', nil, 'c'] so not all are truthy; no injection
    assert_no_match(/\{\|/, cb[:block])
    assert_equal '{ a + c }', cb[:block]
  end

  test 'callback zero args with empty parens does not inject' do
    token = 'void(){ puts "hello" }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal :void, cb[:ret]
    assert_equal [], cb[:args]
    assert_no_match(/\{\|/, cb[:block])
  end

  test 'callback with pointer asterisk separated from type' do
    token = 'int(void *a, void *b){ int(a) <=> int(b) }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal :callback, cb[:kind]
    assert_equal :int, cb[:ret]
    assert_equal %i[voidp voidp], cb[:args]
    assert_match(/\{\|a,b\|/, cb[:block])
    assert_match(/int\(a\) <=> int\(b\)/, cb[:block])
  end

  test 'callback with mixed pointer styles' do
    token = 'int(void* a, void *b){ int(a) + int(b) }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal :callback, cb[:kind]
    assert_equal :int, cb[:ret]
    assert_equal %i[voidp voidp], cb[:args]
    assert_match(/\{\|a,b\|/, cb[:block])
  end

  test 'callback with excessive spaces around asterisk' do
    token = 'int(void * a, void  *  b){ a <=> b }'
    cb = Libcall::Parser.coerce_value(:callback, token)
    assert_equal %i[voidp voidp], cb[:args]
    assert_match(/\{\|a,b\|/, cb[:block])
  end
end
