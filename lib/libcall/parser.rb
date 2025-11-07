# frozen_string_literal: true

require_relative 'type_map'

module Libcall
  # Parse and coerce TYPE VALUE argument pairs for FFI calls
  class Parser
    # Pair-only API helpers
    def self.parse_type(type_str)
      # Callback function pointer: func/callback 'ret(arg,...) { |...| ... }'
      return :callback if %w[func callback].include?(type_str)

      # Output array spec: out:TYPE[N]
      if type_str.start_with?('out:') && type_str.match(/^out:(.+)\[(\d+)\]$/)
        base = Regexp.last_match(1)
        count = Regexp.last_match(2).to_i
        base_sym = TypeMap.lookup(base)
        raise Error, "Unknown output array type: #{base}" unless base_sym

        return [:out_array, base_sym, count]
      end

      # Input array spec: TYPE[] (value as comma-separated list)
      if type_str.end_with?('[]')
        base = type_str[0..-3]
        base_sym = TypeMap.lookup(base)
        raise Error, "Unknown array base type: #{base}" unless base_sym

        return [:array, base_sym]
      end

      # Output pointer spec: out:TYPE (e.g., out:int, out:f64)
      if type_str.start_with?('out:')
        inner = type_str.sub(/^out:/, '')
        inner_sym = TypeMap.lookup(inner)
        raise Error, "Unknown type in out: #{inner}" unless inner_sym

        return [:out, inner_sym]
      end

      type_sym = TypeMap.lookup(type_str)
      raise Error, "Unknown type: #{type_str}" unless type_sym

      type_sym
    end

    def self.parse_return_type(type_str)
      return :void if type_str.nil? || type_str.empty? || type_str == 'void'

      type_sym = TypeMap.lookup(type_str)
      raise Error, "Unknown return type: #{type_str}" unless type_sym

      type_sym
    end

    def self.coerce_value(type_sym, token)
      # Callback value: signature + Ruby block
      if type_sym == :callback
        src = strip_quotes(token.to_s)
        m = src.match(/\A\s*([^(\s]+)\s*\(([^)]*)\)\s*(\{.*\})\s*\z/m)
        raise Error, "Invalid callback spec: #{src}" unless m

        ret_s = m[1].strip
        args_s = m[2].strip
        block_src = m[3]

        ret_sym = TypeMap.lookup(ret_s)
        raise Error, "Unknown callback return type: #{ret_s}" unless ret_sym

        arg_syms = if args_s.empty?
                     []
                   else
                     args_s.split(',').map(&:strip).map do |a|
                       sym = TypeMap.lookup(a)
                       raise Error, "Unknown callback arg type: #{a}" unless sym

                       sym
                     end
                   end

        return { kind: :callback, ret: ret_sym, args: arg_syms, block: block_src }
      end
      # Input array values: comma-separated
      if type_sym.is_a?(Array) && type_sym.first == :array
        base = type_sym[1]
        return [] if token.nil? || token.empty?

        return token.split(',').map { |t| coerce_single_value(base, t.strip) }
      end

      case type_sym
      when *TypeMap::FLOAT_TYPES
        Float(token)
      when *TypeMap::INTEGER_TYPES
        Integer(token)
      when :voidp
        # Accept common null tokens for pointer types
        return 0 if token =~ /\A(null|nil|NULL|0)\z/

        Integer(token)
      when :string
        strip_quotes(token)
      when :void
        raise Error, 'void cannot be used as an argument type'
      else
        raise Error, "Unknown type for coercion: #{type_sym}"
      end
    end

    def self.coerce_single_value(type_sym, token)
      case type_sym
      when *TypeMap::FLOAT_TYPES
        Float(token)
      when *TypeMap::INTEGER_TYPES
        Integer(token)
      when :string
        strip_quotes(token)
      else
        raise Error, "Unknown element type for coercion: #{type_sym}"
      end
    end

    def self.strip_quotes(token)
      if (token.start_with?('"') && token.end_with?('"')) || (token.start_with?("'") && token.end_with?("'"))
        token[1...-1]
      else
        token
      end
    end
  end
end
