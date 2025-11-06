# frozen_string_literal: true

module Libcall
  # Parse and coerce TYPE VALUE argument pairs for FFI calls
  class Parser
    TYPE_MAP = {
      'i8' => :char,
      'u8' => :uchar,
      'i16' => :short,
      'u16' => :ushort,
      'i32' => :int,
      'u32' => :uint,
      'i64' => :long_long,
      'u64' => :ulong_long,
      'isize' => :long,
      'usize' => :ulong,
      'f32' => :float,
      'f64' => :double,
      'cstr' => :string,
      'ptr' => :voidp,
      'void' => :void,
      # Common aliases
      'int' => :int,
      'uint' => :uint,
      'long' => :long,
      'ulong' => :ulong,
      'float' => :float,
      'double' => :double,
      'char' => :char,
      'str' => :string,
      'string' => :string
    }.freeze

    INTEGER_TYPES = %i[int uint long ulong long_long ulong_long char uchar short ushort].freeze
    FLOAT_TYPES = %i[float double].freeze

    # Pair-only API helpers
    def self.parse_type(type_str)
      type_sym = TYPE_MAP[type_str]
      raise Error, "Unknown type: #{type_str}" unless type_sym

      type_sym
    end

    def self.parse_return_type(type_str)
      return :void if type_str.nil? || type_str.empty? || type_str == 'void'

      type_sym = TYPE_MAP[type_str]
      raise Error, "Unknown return type: #{type_str}" unless type_sym

      type_sym
    end

    def self.coerce_value(type_sym, token)
      case type_sym
      when *FLOAT_TYPES
        Float(token)
      when *INTEGER_TYPES, :voidp
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

    def self.fiddle_type(type_sym)
      case type_sym
      when :void then Fiddle::TYPE_VOID
      when :char then Fiddle::TYPE_CHAR
      when :uchar then Fiddle::TYPE_UCHAR
      when :short then Fiddle::TYPE_SHORT
      when :ushort then Fiddle::TYPE_USHORT
      when :int, :uint then Fiddle::TYPE_INT
      when :long, :ulong then Fiddle::TYPE_LONG
      when :long_long, :ulong_long then Fiddle::TYPE_LONG_LONG
      when :float then Fiddle::TYPE_FLOAT
      when :double then Fiddle::TYPE_DOUBLE
      when :voidp, :string then Fiddle::TYPE_VOIDP
      else
        raise Error, "Unknown Fiddle type: #{type_sym}"
      end
    end
  end
end
