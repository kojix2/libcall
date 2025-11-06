# frozen_string_literal: true

require_relative 'type_map'

module Libcall
  # Parse and coerce TYPE VALUE argument pairs for FFI calls
  class Parser
    # Pair-only API helpers
    def self.parse_type(type_str)
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

    def self.strip_quotes(token)
      if (token.start_with?('"') && token.end_with?('"')) || (token.start_with?("'") && token.end_with?("'"))
        token[1...-1]
      else
        token
      end
    end
  end
end
