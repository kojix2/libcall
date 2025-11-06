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
      # Size and pointer-sized integers
      'size_t' => :ulong,
      'ssize_t' => :long,
      'intptr' => :long,
      'uintptr' => :ulong,
      'intptr_t' => :long,
      'uintptr_t' => :ulong,
      'ptrdiff_t' => :long,
      # Boolean
      'bool' => :int,
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
      # Array and output parameters are passed as pointers
      if type_sym.is_a?(Array)
        tag = type_sym.first
        return Fiddle::TYPE_VOIDP if %i[out array out_array].include?(tag)
      end

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

    # Get the size in bytes for a type symbol
    def self.sizeof(type_sym)
      case type_sym
      when :char, :uchar then Fiddle::SIZEOF_CHAR
      when :short, :ushort then Fiddle::SIZEOF_SHORT
      when :int, :uint then Fiddle::SIZEOF_INT
      when :long, :ulong then Fiddle::SIZEOF_LONG
      when :long_long, :ulong_long then Fiddle::SIZEOF_LONG_LONG
      when :float then Fiddle::SIZEOF_FLOAT
      when :double then Fiddle::SIZEOF_DOUBLE
      when :voidp, :string then Fiddle::SIZEOF_VOIDP
      else
        raise Error, "Cannot get size for type: #{type_sym}"
      end
    end

    # Allocate a pointer for output parameter
    def self.allocate_output_pointer(type_sym)
      ptr = Fiddle::Pointer.malloc(sizeof(type_sym))
      # For out:string, we pass char**. Initialize inner pointer to NULL for safety.
      ptr[0, Fiddle::SIZEOF_VOIDP] = [0].pack('J') if type_sym == :string
      ptr
    end

    # Read value from output pointer
    def self.read_output_pointer(ptr, type_sym)
      case type_sym
      when :char then ptr[0, Fiddle::SIZEOF_CHAR].unpack1('c')
      when :uchar then ptr[0, Fiddle::SIZEOF_CHAR].unpack1('C')
      when :short then ptr[0, Fiddle::SIZEOF_SHORT].unpack1('s')
      when :ushort then ptr[0, Fiddle::SIZEOF_SHORT].unpack1('S')
      when :int then ptr[0, Fiddle::SIZEOF_INT].unpack1('i')
      when :uint then ptr[0, Fiddle::SIZEOF_INT].unpack1('I')
      when :long then ptr[0, Fiddle::SIZEOF_LONG].unpack1('l!')
      when :ulong then ptr[0, Fiddle::SIZEOF_LONG].unpack1('L!')
      when :long_long then ptr[0, Fiddle::SIZEOF_LONG_LONG].unpack1('q')
      when :ulong_long then ptr[0, Fiddle::SIZEOF_LONG_LONG].unpack1('Q')
      when :float then ptr[0, Fiddle::SIZEOF_FLOAT].unpack1('f')
      when :double then ptr[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
      when :string
        addr = ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('J')
        return '(null)' if addr.zero?

        begin
          Fiddle::Pointer.new(addr).to_s
        rescue StandardError
          format('0x%x', addr)
        end
      when :voidp then format('0x%x', ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('J'))
      else
        raise Error, "Cannot read output value for type: #{type_sym}"
      end
    end

    # Allocate memory for an array of base type and count elements
    def self.allocate_array(base_type, count)
      Fiddle::Pointer.malloc(sizeof(base_type) * count)
    end

    def self.write_array(ptr, base_type, values)
      return if values.nil? || values.empty?

      bytes = sizeof(base_type) * values.length
      ptr[0, bytes] = values.pack(pack_template(base_type) + values.length.to_s)
    end

    def self.read_array(ptr, base_type, count)
      return [] if count <= 0

      bytes = sizeof(base_type) * count
      raw = ptr[0, bytes]
      raw.unpack(pack_template(base_type) + count.to_s)
    end

    def self.pack_template(base_type)
      case base_type
      when :char then 'c'
      when :uchar then 'C'
      when :short then 's'
      when :ushort then 'S'
      when :int then 'i'
      when :uint then 'I'
      when :long then 'l!'
      when :ulong then 'L!'
      when :long_long then 'q'
      when :ulong_long then 'Q'
      when :float then 'f'
      when :double then 'd'
      else
        raise Error, "Unsupported array base type: #{base_type}"
      end
    end
  end
end
