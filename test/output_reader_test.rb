# frozen_string_literal: true

require 'test_helper'

class OutputReaderTest < Test::Unit::TestCase
  test 'reads single output parameter' do
    ptr = Libcall::TypeMap.allocate_output_pointer(:int)
    ptr[0, Fiddle::SIZEOF_INT] = [42].pack('i')

    out_refs = [{ index: 0, kind: :out, type: :int, ptr: ptr }]
    reader = Libcall::OutputReader.new(out_refs)

    results = reader.read

    assert_equal 1, results.length
    assert_equal 0, results[0][:index]
    assert_equal 'int', results[0][:type]
    assert_equal 42, results[0][:value]
  end

  test 'reads multiple output parameters' do
    ptr1 = Libcall::TypeMap.allocate_output_pointer(:int)
    ptr1[0, Fiddle::SIZEOF_INT] = [10].pack('i')

    ptr2 = Libcall::TypeMap.allocate_output_pointer(:double)
    ptr2[0, Fiddle::SIZEOF_DOUBLE] = [3.14].pack('d')

    out_refs = [
      { index: 0, kind: :out, type: :int, ptr: ptr1 },
      { index: 2, kind: :out, type: :double, ptr: ptr2 }
    ]
    reader = Libcall::OutputReader.new(out_refs)

    results = reader.read

    assert_equal 2, results.length
    assert_equal 10, results[0][:value]
    assert_in_delta 3.14, results[1][:value], 0.001
  end

  test 'reads output array' do
    ptr = Libcall::TypeMap.allocate_array(:int, 3)
    Libcall::TypeMap.write_array(ptr, :int, [1, 2, 3])

    out_refs = [{ index: 0, kind: :out_array, base: :int, count: 3, ptr: ptr }]
    reader = Libcall::OutputReader.new(out_refs)

    results = reader.read

    assert_equal 1, results.length
    assert_equal 'int[3]', results[0][:type]
    assert_equal [1, 2, 3], results[0][:value]
  end

  test 'empty? returns true for no output parameters' do
    reader = Libcall::OutputReader.new([])

    assert_true reader.empty?
  end

  test 'empty? returns false when output parameters exist' do
    ptr = Libcall::TypeMap.allocate_output_pointer(:int)
    out_refs = [{ index: 0, kind: :out, type: :int, ptr: ptr }]
    reader = Libcall::OutputReader.new(out_refs)

    assert_false reader.empty?
  end

  test 'raises error for unknown output reference kind' do
    ptr = Libcall::TypeMap.allocate_output_pointer(:int)
    out_refs = [{ index: 0, kind: :unknown, type: :int, ptr: ptr }]
    reader = Libcall::OutputReader.new(out_refs)

    assert_raise(Libcall::Error) do
      reader.read
    end
  end
end
