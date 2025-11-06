# frozen_string_literal: true

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
  end
end
