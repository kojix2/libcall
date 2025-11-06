# frozen_string_literal: true

require 'fiddle'

module Libcall
  # Type mapping for FFI calls
  module TypeMap
    # Map from string type names to FFI type symbols
    MAP = {
      # Short type names (Rust-like)
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
      # Pointer types
      'cstr' => :string,
      'ptr' => :voidp,
      'pointer' => :voidp,
      'void' => :void,
      # Common C type names
      'char' => :char,
      'short' => :short,
      'ushort' => :ushort,
      'int' => :int,
      'uint' => :uint,
      'long' => :long,
      'ulong' => :ulong,
      'float' => :float,
      'double' => :double,
      # Extended type names (stdint-like)
      'int8' => :char,
      'uint8' => :uchar,
      'int16' => :short,
      'uint16' => :ushort,
      'int32' => :int,
      'uint32' => :uint,
      'int64' => :long_long,
      'uint64' => :ulong_long,
      'float32' => :float,
      'float64' => :double,
      # String aliases
      'str' => :string,
      'string' => :string
    }.freeze

    # Integer type symbols
    INTEGER_TYPES = %i[
      int uint
      long ulong
      long_long ulong_long
      char uchar
      short ushort
    ].freeze

    # Floating point type symbols
    FLOAT_TYPES = %i[float double].freeze

    # Look up FFI type symbol from string
    def self.lookup(type_str)
      MAP[type_str]
    end

    # Check if type symbol is an integer type
    def self.integer_type?(type_sym)
      INTEGER_TYPES.include?(type_sym)
    end

    # Check if type symbol is a floating point type
    def self.float_type?(type_sym)
      FLOAT_TYPES.include?(type_sym)
    end

    # Convert type symbol to Fiddle type constant
    def self.to_fiddle_type(type_sym)
      # Output parameters are passed as pointers
      return Fiddle::TYPE_VOIDP if type_sym.is_a?(Array) && type_sym.first == :out

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
