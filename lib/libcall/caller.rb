# frozen_string_literal: true

require 'fiddle'

module Libcall
  # Execute C function calls via Fiddle FFI
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
      out_refs = []

      arg_pairs.each_with_index do |(type_sym, value), idx|
        arg_types << TypeMap.to_fiddle_type(type_sym)

        if type_sym.is_a?(Array) && type_sym.first == :out
          inner = type_sym[1]
          ptr = TypeMap.allocate_output_pointer(inner)
          out_refs << { index: idx, type: inner, ptr: ptr }
          arg_values << ptr.to_i
        else
          arg_values << value
        end
      end

      ret_type = TypeMap.to_fiddle_type(return_type)

      handle = Fiddle.dlopen(lib_path)
      func_ptr = handle[func_name]
      func = Fiddle::Function.new(func_ptr, arg_types, ret_type)

      raw_result = func.call(*arg_values)
      formatted_result = format_result(raw_result, return_type)

      if out_refs.empty?
        formatted_result
      else
        { result: formatted_result, outputs: read_output_values(out_refs) }
      end
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

    def read_output_values(out_refs)
      out_refs.map do |ref|
        value = TypeMap.read_output_pointer(ref[:ptr], ref[:type])
        { index: ref[:index], type: ref[:type].to_s, value: value }
      end
    end
  end
end
