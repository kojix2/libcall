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
      processor = ArgumentProcessor.new(arg_pairs)
      processed = processor.process

      raw_result = execute_function(processed)
      formatted_result = format_result(raw_result, return_type)

      output_reader = OutputReader.new(processed.out_refs)
      if output_reader.empty?
        formatted_result
      else
        { result: formatted_result, outputs: output_reader.read }
      end
    rescue Fiddle::DLError => e
      raise Error, "Failed to load library or function: #{e.message}"
    end

    private

    def execute_function(processed)
      handle = Fiddle.dlopen(lib_path)
      func_ptr = handle[func_name]
      ret_type = TypeMap.to_fiddle_type(return_type)
      func = Fiddle::Function.new(func_ptr, processed.arg_types, ret_type)
      func.call(*processed.arg_values)
    end

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
