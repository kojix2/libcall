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

        if type_sym.is_a?(Array)
          case type_sym.first
          when :out
            inner = type_sym[1]
            ptr = TypeMap.allocate_output_pointer(inner)
            out_refs << { index: idx, kind: :out, type: inner, ptr: ptr }
            arg_values << ptr.to_i
          when :array
            base = type_sym[1]
            values = Array(value)
            ptr = TypeMap.allocate_array(base, values.length)
            TypeMap.write_array(ptr, base, values)
            arg_values << ptr.to_i
          when :out_array
            base = type_sym[1]
            count = type_sym[2]
            ptr = TypeMap.allocate_array(base, count)
            out_refs << { index: idx, kind: :out_array, base: base, count: count, ptr: ptr }
            arg_values << ptr.to_i
          else
            raise Error, "Unknown array/output form: #{type_sym.inspect}"
          end
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
        case ref[:kind]
        when :out
          value = TypeMap.read_output_pointer(ref[:ptr], ref[:type])
          { index: ref[:index], type: ref[:type].to_s, value: value }
        when :out_array
          base = ref[:base]
          count = ref[:count]
          values = TypeMap.read_array(ref[:ptr], base, count)
          { index: ref[:index], type: "#{base}[#{count}]", value: values }
        else
          raise Error, "Unknown out reference kind: #{ref[:kind]}"
        end
      end
    end
  end
end
