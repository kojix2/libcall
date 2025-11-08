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
      closures = []

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
            arg_values << ptr.to_i
          else
            raise Error, "Unknown array/output form: #{type_sym.inspect}"
          end
        elsif type_sym == :callback
          spec = value
          unless spec.is_a?(Hash) && spec[:kind] == :callback
            raise Error, 'Invalid callback value; expected func signature and block'
          end

          ret_ty = TypeMap.to_fiddle_type(spec[:ret])
          arg_tys = spec[:args].map { |a| TypeMap.to_fiddle_type(a) }
          # Build Ruby proc from block source, e.g., "{|a,b| a+b}"
          # Evaluate proc in a helper context so DSL methods are available
          ctx = Object.new.extend(Libcall::Fiddley::DSL)
          begin
            ruby_proc = ctx.instance_eval("proc #{spec[:block]}", __FILE__, __LINE__)
          rescue SyntaxError => e
            raise Error, "Invalid Ruby block for callback: #{e.message}"
          end
          closure = Fiddle::Closure::BlockCaller.new(ret_ty, arg_tys) do |*cb_args|
            # Convert pointer-typed args to Fiddle::Pointer for convenience
            cooked = cb_args.each_with_index.map do |v, i|
              at = spec[:args][i]
              if at == :voidp
                Fiddle::Pointer.new(v)
              else
                v
              end
            end
            ruby_proc.call(*cooked)
          end
          closures << closure # keep alive during call
          arg_values << closure
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
