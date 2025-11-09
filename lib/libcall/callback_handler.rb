# frozen_string_literal: true

require 'fiddle'

module Libcall
  # Handles callback function pointer creation for FFI calls
  class CallbackHandler
    attr_reader :spec

    def self.create(spec)
      new(spec).create_closure
    end

    def initialize(spec)
      @spec = spec
      validate_spec!
    end

    def create_closure
      ret_ty = TypeMap.to_fiddle_type(@spec[:ret])
      arg_tys = @spec[:args].map { |a| TypeMap.to_fiddle_type(a) }
      ruby_proc = build_proc

      Fiddle::Closure::BlockCaller.new(ret_ty, arg_tys) do |*cb_args|
        cooked_args = cook_arguments(cb_args)
        ruby_proc.call(*cooked_args)
      end
    end

    private

    def validate_spec!
      return if @spec.is_a?(Hash) && @spec[:kind] == :callback

      raise Error, 'Invalid callback value; expected func signature and block'
    end

    def build_proc
      ctx = Object.new.extend(Fiddley::DSL)
      ctx.instance_eval("proc #{@spec[:block]}", __FILE__, __LINE__)
    rescue SyntaxError => e
      raise Error, "Invalid Ruby block for callback: #{e.message}"
    end

    def cook_arguments(cb_args)
      cb_args.each_with_index.map do |v, i|
        at = @spec[:args][i]
        at == :voidp ? Fiddle::Pointer.new(v) : v
      end
    end
  end
end
