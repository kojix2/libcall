# frozen_string_literal: true

# A tiny helper layer inspired by fiddley (BSD-2-Clause) to offer
# convenient, DSL-friendly utilities on top of Ruby's Fiddle.
# This is intentionally small and tailored for libcall use-cases.

require 'fiddle'

module Libcall
  module Fiddley
    module Utils
      module_function

      # Native size_t pack template and size
      SIZET_PACK = (Fiddle::SIZEOF_VOIDP == Fiddle::SIZEOF_LONG ? 'L!' : 'Q')

      # Return size in bytes for a given type symbol.
      # Falls back to pointer size for :pointer and :voidp.
      def sizeof(type)
        return Fiddle::SIZEOF_SIZE_T if type == :size_t
        return Fiddle::SIZEOF_VOIDP if type == :pointer || type == :voidp

        # Delegate to Libcall::TypeMap when possible
        Libcall::TypeMap.sizeof(type)
      rescue StandardError
        raise Libcall::Error, "unknown type for sizeof: #{type}"
      end

      # Convert a type symbol to a Fiddle type constant.
      def to_fiddle_type(type)
        return Fiddle::TYPE_SIZE_T if type == :size_t
        return Fiddle::TYPE_VOIDP if type == :pointer || type == :voidp

        Libcall::TypeMap.to_fiddle_type(type)
      rescue StandardError
        raise Libcall::Error, "unknown type for to_fiddle_type: #{type}"
      end

      # Pack template for array values of given base type.
      def array_pack_template(type)
        return SIZET_PACK if type == :size_t

        # Use TypeMap's packing for standard types
        Libcall::TypeMap.pack_template(type)
      rescue StandardError
        # For generic pointers/addresses, use native unsigned pointer width
        return 'J' if type == :pointer || type == :voidp
        raise Libcall::Error, "Unsupported array base type: #{type}"
      end

      # Convert Ruby array of numbers to a binary string for the given type
      def array2str(type, array)
        array.pack("#{array_pack_template(type)}*")
      end

      # Convert binary string to Ruby array of the given type
      def str2array(type, str)
        str.unpack("#{array_pack_template(type)}*")
      end
    end

    # Minimal memory buffer wrapper to make building args/arrays convenient
    class MemoryPointer
      attr_reader :size

      def initialize(type, count = 1)
        @type = type
        @size = Utils.sizeof(type) * count
        @ptr = Fiddle::Pointer.malloc(@size)
      end

      def to_ptr
        @ptr
      end

      def address
        @ptr.to_i
      end

      def write_array(type, values)
        data = Utils.array2str(type, Array(values))
        @ptr[0, data.bytesize] = data
        self
      end

      def read_array(type, count)
        bytes = Utils.sizeof(type) * count
        Utils.str2array(type, @ptr[0, bytes])
      end

      def put_bytes(offset, str)
        @ptr[offset, str.bytesize] = str
      end

      def write_bytes(str)
        put_bytes(0, str)
      end

      def get_bytes(offset, len)
        @ptr[offset, len]
      end

      def read_bytes(len)
        get_bytes(0, len)
      end

      # Return Fiddle::Pointer stored at this pointer (read void*)
      def read_pointer
        to_ptr.ptr
      end
    end

    # Wrap Fiddle::Closure::BlockCaller with friendlier type mapping
    class Function < Fiddle::Closure::BlockCaller
      def initialize(ret, params, &blk)
        r = Utils.to_fiddle_type(ret)
        p = Array(params).map { |t| Utils.to_fiddle_type(t) }
        super(r, p, &blk)
      end
    end
  end
end
