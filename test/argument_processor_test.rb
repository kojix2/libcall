# frozen_string_literal: true

require 'test_helper'

class ArgumentProcessorTest < Test::Unit::TestCase
  test 'processes simple scalar arguments' do
    processor = Libcall::ArgumentProcessor.new([[:int, 42], [:double, 3.14]])
    result = processor.process

    assert_equal 2, result.arg_types.length
    assert_equal [42, 3.14], result.arg_values
    assert_empty result.out_refs
    assert_empty result.closures
  end

  test 'processes output pointer arguments' do
    processor = Libcall::ArgumentProcessor.new([[%i[out int], nil]])
    result = processor.process

    assert_equal 1, result.arg_types.length
    assert_equal Fiddle::TYPE_VOIDP, result.arg_types[0]
    assert_equal 1, result.out_refs.length
    assert_equal :out, result.out_refs[0][:kind]
    assert_equal :int, result.out_refs[0][:type]
  end

  test 'processes input array arguments' do
    processor = Libcall::ArgumentProcessor.new([[%i[array int], [1, 2, 3]]])
    result = processor.process

    assert_equal 1, result.arg_types.length
    assert_equal Fiddle::TYPE_VOIDP, result.arg_types[0]
    assert_kind_of Integer, result.arg_values[0]
  end

  test 'processes output array arguments' do
    processor = Libcall::ArgumentProcessor.new([[[:out_array, :int, 5], nil]])
    result = processor.process

    assert_equal 1, result.arg_types.length
    assert_equal 1, result.out_refs.length
    assert_equal :out_array, result.out_refs[0][:kind]
    assert_equal :int, result.out_refs[0][:base]
    assert_equal 5, result.out_refs[0][:count]
  end

  test 'processes output array with initializer' do
    processor = Libcall::ArgumentProcessor.new([[[:out_array, :int, 3], [1, 2, 3]]])
    result = processor.process

    assert_equal 1, result.out_refs.length
    assert_equal 3, result.out_refs[0][:count]
  end

  test 'raises error for mismatched initializer length' do
    processor = Libcall::ArgumentProcessor.new([[[:out_array, :int, 5], [1, 2, 3]]])

    assert_raise(Libcall::Error) do
      processor.process
    end
  end

  test 'processes callback arguments' do
    callback_spec = {
      kind: :callback,
      ret: :int,
      args: %i[int int],
      block: '{|a,b| a+b}'
    }
    processor = Libcall::ArgumentProcessor.new([[:callback, callback_spec]])
    result = processor.process

    assert_equal 1, result.arg_types.length
    assert_equal Fiddle::TYPE_VOIDP, result.arg_types[0]
    assert_equal 1, result.closures.length
    assert_kind_of Fiddle::Closure::BlockCaller, result.closures[0]
  end

  test 'processes mixed argument types' do
    callback_spec = {
      kind: :callback,
      ret: :int,
      args: %i[int int],
      block: '{|a,b| a+b}'
    }
    processor = Libcall::ArgumentProcessor.new([
                                                 [:int, 10],
                                                 [%i[out double], nil],
                                                 [:callback, callback_spec]
                                               ])
    result = processor.process

    assert_equal 3, result.arg_types.length
    assert_equal 1, result.out_refs.length
    assert_equal 1, result.closures.length
  end
end
