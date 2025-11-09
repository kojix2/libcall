# frozen_string_literal: true

module Libcall
  # Processes argument pairs for FFI calls
  class ArgumentProcessor
    # Value object to hold processed arguments
    ProcessedArguments = Struct.new(
      :arg_types,
      :arg_values,
      :out_refs,
      :closures,
      keyword_init: true
    )

    def initialize(arg_pairs)
      @arg_pairs = arg_pairs
    end

    def process
      arg_types = []
      arg_values = []
      out_refs = []
      closures = []

      @arg_pairs.each_with_index do |(type_sym, value), idx|
        if type_sym.is_a?(Array)
          process_complex_type(type_sym, value, idx, arg_types, arg_values, out_refs)
        elsif type_sym == :callback
          process_callback(value, arg_types, arg_values, closures)
        else
          arg_types << TypeMap.to_fiddle_type(type_sym)
          arg_values << value
        end
      end

      ProcessedArguments.new(
        arg_types: arg_types,
        arg_values: arg_values,
        out_refs: out_refs,
        closures: closures
      )
    end

    private

    def process_complex_type(type_sym, value, idx, arg_types, arg_values, out_refs)
      case type_sym.first
      when :out
        process_output_pointer(type_sym, idx, arg_types, arg_values, out_refs)
      when :array
        process_input_array(type_sym, value, arg_types, arg_values)
      when :out_array
        process_output_array(type_sym, value, idx, arg_types, arg_values, out_refs)
      else
        raise Error, "Unknown array/output form: #{type_sym.inspect}"
      end
    end

    def process_output_pointer(type_sym, idx, arg_types, arg_values, out_refs)
      inner = type_sym[1]
      ptr = TypeMap.allocate_output_pointer(inner)
      out_refs << { index: idx, kind: :out, type: inner, ptr: ptr }
      arg_types << TypeMap.to_fiddle_type(type_sym)
      arg_values << ptr.to_i
    end

    def process_input_array(type_sym, value, arg_types, arg_values)
      base = type_sym[1]
      values = Array(value)
      ptr = TypeMap.allocate_array(base, values.length)
      TypeMap.write_array(ptr, base, values)
      arg_types << TypeMap.to_fiddle_type(type_sym)
      arg_values << ptr.to_i
    end

    def process_output_array(type_sym, value, idx, arg_types, arg_values, out_refs)
      base = type_sym[1]
      count = type_sym[2]
      ptr = TypeMap.allocate_array(base, count)

      # Optional initializer values
      if value
        vals = Array(value)
        unless vals.length == count
          raise Error,
                "Initializer length #{vals.length} does not match out array size #{count}"
        end

        TypeMap.write_array(ptr, base, vals)
      end

      out_refs << { index: idx, kind: :out_array, base: base, count: count, ptr: ptr }
      arg_types << TypeMap.to_fiddle_type(type_sym)
      arg_values << ptr.to_i
    end

    def process_callback(value, arg_types, arg_values, closures)
      closure = CallbackHandler.create(value)
      closures << closure # keep alive during call
      arg_types << TypeMap.to_fiddle_type(:callback)
      arg_values << closure
    end
  end
end
