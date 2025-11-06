# frozen_string_literal: true

require 'fiddle'

module Libcall
  class Caller
    attr_reader :lib_path, :func_name, :return_type, :arg_pairs

    def initialize(lib_path, func_name, arg_pairs: [], return_type: :void)
      @lib_path = lib_path
      @func_name = func_name
      @return_type = return_type
      @arg_pairs = arg_pairs
    end

    def call
      arg_types = []
      arg_values = []

      arg_pairs.each do |type_sym, value|
        arg_types << Parser.fiddle_type(type_sym)
        arg_values << value
      end

      ret_type = Parser.fiddle_type(return_type)

      handle = Fiddle.dlopen(lib_path)
      func_ptr = handle[func_name]
      func = Fiddle::Function.new(func_ptr, arg_types, ret_type)

      result = func.call(*arg_values)

      format_result(result, return_type)
    rescue Fiddle::DLError => e
      raise Error, "Failed to load library or function: #{e.message}"
    end

    private

    def format_result(result, type)
      case type
      when :void
        nil
      when :string, :cstr
        addr = result.to_i
        return '(null)' if addr.zero?

        begin
          Fiddle::Pointer.new(addr).to_s
        rescue StandardError
          format('0x%x', addr)
        end
      when :float, :double
        result.to_f
      when :voidp, :ptr
        format('0x%x', result.to_i)
      else
        result
      end
    end
  end
end
