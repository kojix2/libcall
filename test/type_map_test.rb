# frozen_string_literal: true

require 'test_helper'

class TypeMapTest < Test::Unit::TestCase
  # ========================================
  # Type lookup tests
  # ========================================

  test 'lookup returns correct type symbols for short type names (Rust-like)' do
    assert_equal :char, Libcall::TypeMap.lookup('i8')
    assert_equal :uchar, Libcall::TypeMap.lookup('u8')
    assert_equal :short, Libcall::TypeMap.lookup('i16')
    assert_equal :ushort, Libcall::TypeMap.lookup('u16')
    assert_equal :int, Libcall::TypeMap.lookup('i32')
    assert_equal :uint, Libcall::TypeMap.lookup('u32')
    assert_equal :long_long, Libcall::TypeMap.lookup('i64')
    assert_equal :ulong_long, Libcall::TypeMap.lookup('u64')
    assert_equal :float, Libcall::TypeMap.lookup('f32')
    assert_equal :double, Libcall::TypeMap.lookup('f64')
  end

  test 'lookup returns correct type symbols for C type names' do
    assert_equal :char, Libcall::TypeMap.lookup('char')
    assert_equal :short, Libcall::TypeMap.lookup('short')
    assert_equal :ushort, Libcall::TypeMap.lookup('ushort')
    assert_equal :int, Libcall::TypeMap.lookup('int')
    assert_equal :uint, Libcall::TypeMap.lookup('uint')
    assert_equal :long, Libcall::TypeMap.lookup('long')
    assert_equal :ulong, Libcall::TypeMap.lookup('ulong')
    assert_equal :float, Libcall::TypeMap.lookup('float')
    assert_equal :double, Libcall::TypeMap.lookup('double')
  end

  test 'lookup returns correct type symbols for extended type names' do
    assert_equal :char, Libcall::TypeMap.lookup('int8')
    assert_equal :uchar, Libcall::TypeMap.lookup('uint8')
    assert_equal :short, Libcall::TypeMap.lookup('int16')
    assert_equal :ushort, Libcall::TypeMap.lookup('uint16')
    assert_equal :int, Libcall::TypeMap.lookup('int32')
    assert_equal :uint, Libcall::TypeMap.lookup('uint32')
    assert_equal :long_long, Libcall::TypeMap.lookup('int64')
    assert_equal :ulong_long, Libcall::TypeMap.lookup('uint64')
    assert_equal :float, Libcall::TypeMap.lookup('float32')
    assert_equal :double, Libcall::TypeMap.lookup('float64')
  end

  test 'lookup returns correct type symbols for size/ptr/boolean aliases' do
    assert_equal :ulong, Libcall::TypeMap.lookup('size_t')
    assert_equal :long, Libcall::TypeMap.lookup('ssize_t')
    assert_equal :long, Libcall::TypeMap.lookup('intptr')
    assert_equal :ulong, Libcall::TypeMap.lookup('uintptr')
    assert_equal :long, Libcall::TypeMap.lookup('intptr_t')
    assert_equal :ulong, Libcall::TypeMap.lookup('uintptr_t')
    assert_equal :long, Libcall::TypeMap.lookup('ptrdiff_t')
    assert_equal :int, Libcall::TypeMap.lookup('bool')
  end

  test 'lookup returns correct type symbols for pointer types' do
    assert_equal :string, Libcall::TypeMap.lookup('cstr')
    assert_equal :string, Libcall::TypeMap.lookup('str')
    assert_equal :string, Libcall::TypeMap.lookup('string')
    assert_equal :voidp, Libcall::TypeMap.lookup('ptr')
    assert_equal :voidp, Libcall::TypeMap.lookup('pointer')
    assert_equal :void, Libcall::TypeMap.lookup('void')
  end

  test 'lookup returns correct type symbols for size types' do
    assert_equal :long, Libcall::TypeMap.lookup('isize')
    assert_equal :ulong, Libcall::TypeMap.lookup('usize')
  end

  test 'lookup returns nil for unknown types' do
    assert_nil Libcall::TypeMap.lookup('unknown')
    assert_nil Libcall::TypeMap.lookup('foo')
    assert_nil Libcall::TypeMap.lookup('')
  end

  test 'MAP contains all expected type aliases' do
    # Verify we have multiple ways to specify the same type
    assert_equal Libcall::TypeMap.lookup('int'), Libcall::TypeMap.lookup('i32')
    assert_equal Libcall::TypeMap.lookup('int'), Libcall::TypeMap.lookup('int32')
    assert_equal Libcall::TypeMap.lookup('float'), Libcall::TypeMap.lookup('f32')
    assert_equal Libcall::TypeMap.lookup('float'), Libcall::TypeMap.lookup('float32')
    assert_equal Libcall::TypeMap.lookup('double'), Libcall::TypeMap.lookup('f64')
    assert_equal Libcall::TypeMap.lookup('double'), Libcall::TypeMap.lookup('float64')
  end

  # ========================================
  # Type checking predicates
  # ========================================

  test 'integer_type? returns true for integer types' do
    assert_true Libcall::TypeMap.integer_type?(:int)
    assert_true Libcall::TypeMap.integer_type?(:uint)
    assert_true Libcall::TypeMap.integer_type?(:long)
    assert_true Libcall::TypeMap.integer_type?(:ulong)
    assert_true Libcall::TypeMap.integer_type?(:long_long)
    assert_true Libcall::TypeMap.integer_type?(:ulong_long)
    assert_true Libcall::TypeMap.integer_type?(:char)
    assert_true Libcall::TypeMap.integer_type?(:uchar)
    assert_true Libcall::TypeMap.integer_type?(:short)
    assert_true Libcall::TypeMap.integer_type?(:ushort)
  end

  test 'integer_type? returns false for non-integer types' do
    assert_false Libcall::TypeMap.integer_type?(:float)
    assert_false Libcall::TypeMap.integer_type?(:double)
    assert_false Libcall::TypeMap.integer_type?(:void)
    assert_false Libcall::TypeMap.integer_type?(:voidp)
    assert_false Libcall::TypeMap.integer_type?(:string)
  end

  test 'float_type? returns true for floating point types' do
    assert_true Libcall::TypeMap.float_type?(:float)
    assert_true Libcall::TypeMap.float_type?(:double)
  end

  test 'float_type? returns false for non-floating point types' do
    assert_false Libcall::TypeMap.float_type?(:int)
    assert_false Libcall::TypeMap.float_type?(:uint)
    assert_false Libcall::TypeMap.float_type?(:void)
    assert_false Libcall::TypeMap.float_type?(:voidp)
    assert_false Libcall::TypeMap.float_type?(:string)
  end

  # ========================================
  # Fiddle type conversion
  # ========================================

  test 'to_fiddle_type returns correct Fiddle types for basic types' do
    assert_equal Fiddle::TYPE_VOID, Libcall::TypeMap.to_fiddle_type(:void)
    assert_equal Fiddle::TYPE_CHAR, Libcall::TypeMap.to_fiddle_type(:char)
    assert_equal Fiddle::TYPE_UCHAR, Libcall::TypeMap.to_fiddle_type(:uchar)
    assert_equal Fiddle::TYPE_SHORT, Libcall::TypeMap.to_fiddle_type(:short)
    assert_equal Fiddle::TYPE_USHORT, Libcall::TypeMap.to_fiddle_type(:ushort)
    assert_equal Fiddle::TYPE_INT, Libcall::TypeMap.to_fiddle_type(:int)
    assert_equal Fiddle::TYPE_INT, Libcall::TypeMap.to_fiddle_type(:uint)
    assert_equal Fiddle::TYPE_LONG, Libcall::TypeMap.to_fiddle_type(:long)
    assert_equal Fiddle::TYPE_LONG, Libcall::TypeMap.to_fiddle_type(:ulong)
    assert_equal Fiddle::TYPE_LONG_LONG, Libcall::TypeMap.to_fiddle_type(:long_long)
    assert_equal Fiddle::TYPE_LONG_LONG, Libcall::TypeMap.to_fiddle_type(:ulong_long)
    assert_equal Fiddle::TYPE_FLOAT, Libcall::TypeMap.to_fiddle_type(:float)
    assert_equal Fiddle::TYPE_DOUBLE, Libcall::TypeMap.to_fiddle_type(:double)
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(:voidp)
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(:string)
  end

  test 'to_fiddle_type raises error for unknown types' do
    assert_raise(Libcall::Error) do
      Libcall::TypeMap.to_fiddle_type(:unknown)
    end
  end

  # ========================================
  # Constant immutability
  # ========================================

  test 'MAP is frozen' do
    assert_true Libcall::TypeMap::MAP.frozen?
  end

  test 'INTEGER_TYPES is frozen' do
    assert_true Libcall::TypeMap::INTEGER_TYPES.frozen?
  end

  test 'FLOAT_TYPES is frozen' do
    assert_true Libcall::TypeMap::FLOAT_TYPES.frozen?
  end

  # ========================================
  # Type size queries
  # ========================================

  test 'sizeof returns expected sizes for select types' do
    assert_equal Fiddle::SIZEOF_INT, Libcall::TypeMap.sizeof(:int)
    assert_equal Fiddle::SIZEOF_DOUBLE, Libcall::TypeMap.sizeof(:double)
    assert_equal Fiddle::SIZEOF_VOIDP, Libcall::TypeMap.sizeof(:voidp)
    assert_equal Fiddle::SIZEOF_VOIDP, Libcall::TypeMap.sizeof(:string)
  end

  # ========================================
  # Array and output parameter support
  # ========================================

  test 'to_fiddle_type returns VOIDP for output parameters' do
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(%i[out int])
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(%i[out double])
    assert_equal Fiddle::TYPE_VOIDP, Libcall::TypeMap.to_fiddle_type(%i[out char])
  end
end
