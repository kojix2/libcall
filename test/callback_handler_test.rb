# frozen_string_literal: true

require 'test_helper'

class CallbackHandlerTest < Test::Unit::TestCase
  test 'creates closure for simple callback' do
    spec = {
      kind: :callback,
      ret: :int,
      args: %i[int int],
      block: '{|a,b| a + b}'
    }

    closure = Libcall::CallbackHandler.create(spec)

    assert_kind_of Fiddle::Closure::BlockCaller, closure
  end

  test 'raises error for invalid spec' do
    invalid_spec = { foo: :bar }

    assert_raise(Libcall::Error) do
      Libcall::CallbackHandler.create(invalid_spec)
    end
  end

  test 'raises error for invalid Ruby block syntax' do
    spec = {
      kind: :callback,
      ret: :int,
      args: %i[int int],
      block: '{|a,b| invalid syntax here @@'
    }

    assert_raise(Libcall::Error) do
      Libcall::CallbackHandler.create(spec)
    end
  end

  test 'creates closure that executes Ruby code' do
    spec = {
      kind: :callback,
      ret: :int,
      args: %i[int int],
      block: '{|a,b| a * 2 + b}'
    }

    closure = Libcall::CallbackHandler.create(spec)

    # Closure should be callable
    assert_kind_of Fiddle::Closure::BlockCaller, closure
  end

  test 'creates closure with void* arguments' do
    spec = {
      kind: :callback,
      ret: :int,
      args: %i[voidp voidp],
      block: '{|a,b| 0}'
    }

    closure = Libcall::CallbackHandler.create(spec)

    assert_kind_of Fiddle::Closure::BlockCaller, closure
  end
end
