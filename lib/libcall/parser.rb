# frozen_string_literal: true

module Libcall
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
      'int' => :int,
      'uint' => :uint,
      'long' => :long,
      'ulong' => :ulong,
      'float' => :float,
      'double' => :double,
      'char' => :char,
      'str' => :string
    }.freeze

    def self.parse_arg(arg)
      return [:string, ''] if arg.empty?

      if (arg.start_with?('"') && arg.end_with?('"')) ||
         (arg.start_with?("'") && arg.end_with?("'"))
        return [:string, arg[1...-1]]
      end

      if arg =~ /^([-+]?(?:\d+\.?\d*|\d*\.\d+))([a-z]\d+|[a-z]+)$/i
        value_str = ::Regexp.last_match(1)
        type_str = ::Regexp.last_match(2)

        type_sym = TYPE_MAP[type_str]
        raise Error, "Unknown type suffix: #{type_str}" unless type_sym

        value = if %i[float double].include?(type_sym)
                  value_str.to_f
                else
                  value_str.to_i
                end

        return [type_sym, value]
      end

      if arg =~ /^[-+]?\d+$/
        [:int, arg.to_i]
      elsif arg =~ /^[-+]?(?:\d+\.\d*|\d*\.\d+)$/
        [:double, arg.to_f]
      else
        raise Error, "Cannot parse argument: #{arg}"
      end
    end

    def self.parse_return_type(type_str)
      return :void if type_str.nil? || type_str.empty? || type_str == 'void'

      type_sym = TYPE_MAP[type_str]
      raise Error, "Unknown return type: #{type_str}" unless type_sym

      type_sym
    end

    def self.parse_signature(sig)
      raise Error, "Invalid signature format: #{sig}" unless sig =~ /^([a-z]\w*)\((.*)\)$/i

      ret_type = parse_return_type(::Regexp.last_match(1))
      arg_types = ::Regexp.last_match(2).split(',').map(&:strip).reject(&:empty?).map do |t|
        TYPE_MAP[t] or raise Error, "Unknown type in signature: #{t}"
      end
      [ret_type, arg_types]
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
