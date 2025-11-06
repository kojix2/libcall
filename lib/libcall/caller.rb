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
          ptr = allocate_output_pointer(inner)
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

    def allocate_output_pointer(type_sym)
      size = case type_sym
             when :char, :uchar then Fiddle::SIZEOF_CHAR
             when :short, :ushort then Fiddle::SIZEOF_SHORT
             when :int, :uint then Fiddle::SIZEOF_INT
             when :long, :ulong then Fiddle::SIZEOF_LONG
             when :long_long, :ulong_long then Fiddle::SIZEOF_LONG_LONG
             when :float then Fiddle::SIZEOF_FLOAT
             when :double then Fiddle::SIZEOF_DOUBLE
             when :voidp then Fiddle::SIZEOF_VOIDP
             else
               raise Error, "Cannot allocate output pointer for type: #{type_sym}"
             end
      Fiddle::Pointer.malloc(size)
    end

    def read_output_values(out_refs)
      out_refs.map do |ref|
        value = case ref[:type]
                when :char then ref[:ptr][0, Fiddle::SIZEOF_CHAR].unpack1('c')
                when :uchar then ref[:ptr][0, Fiddle::SIZEOF_CHAR].unpack1('C')
                when :short then ref[:ptr][0, Fiddle::SIZEOF_SHORT].unpack1('s')
                when :ushort then ref[:ptr][0, Fiddle::SIZEOF_SHORT].unpack1('S')
                when :int then ref[:ptr][0, Fiddle::SIZEOF_INT].unpack1('i')
                when :uint then ref[:ptr][0, Fiddle::SIZEOF_INT].unpack1('I')
                when :long then ref[:ptr][0, Fiddle::SIZEOF_LONG].unpack1('l!')
                when :ulong then ref[:ptr][0, Fiddle::SIZEOF_LONG].unpack1('L!')
                when :long_long then ref[:ptr][0, Fiddle::SIZEOF_LONG_LONG].unpack1('q')
                when :ulong_long then ref[:ptr][0, Fiddle::SIZEOF_LONG_LONG].unpack1('Q')
                when :float then ref[:ptr][0, Fiddle::SIZEOF_FLOAT].unpack1('f')
                when :double then ref[:ptr][0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
                when :voidp then format('0x%x', ref[:ptr][0, Fiddle::SIZEOF_VOIDP].unpack1('J'))
                else
                  raise Error, "Cannot read output value for type: #{ref[:type]}"
                end

        { index: ref[:index], type: ref[:type].to_s, value: value }
      end
    end
  end
end
