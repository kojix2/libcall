# frozen_string_literal: true

require 'json'
require_relative 'platform'

module Libcall
  # Command-line interface for calling C functions from shared libraries
  class CLI
    PLATFORM_EXAMPLES = {
      windows: <<~EXAMPLES.chomp,
        libcall -lmsvcrt puts string "Hello from libcall" -r int
        libcall -lKernel32 GetTickCount -r uint32
        libcall -lmsvcrt getenv string "PATH" -r string
      EXAMPLES
      darwin: <<~EXAMPLES.chomp,
        libcall -lSystem getpid -r int
        libcall -lSystem puts string "Hello from libcall" -r int
        libcall -lSystem getenv string "PATH" -r string
      EXAMPLES
      unix: <<~EXAMPLES.chomp
        libcall -lm sqrt double 16 -r double
        libcall -lc getpid -r int
        libcall -lc getenv string "PATH" -r string
      EXAMPLES
    }.freeze

    def initialize(argv)
      @argv = argv
      @options = {
        dry_run: false,
        json: false,
        verbose: false,
        return_type: :void,
        lib: nil,
        lib_name: nil,
        lib_paths: []
      }
    end

    def run
      lib_path, func_name, arg_pairs = scan_argv!(@argv)

      # Resolve library path if a library name (-l) was given
      if @options[:lib_name]
        finder = LibraryFinder.new(lib_paths: @options[:lib_paths])
        lib_path = finder.find(@options[:lib_name])
      end

      if lib_path.nil? || func_name.nil?
        warn 'Error: Missing required arguments'
        warn 'Usage: libcall [OPTIONS] <LIBRARY> <FUNCTION> (TYPE VALUE)...'
        exit 1
      end

      if @options[:verbose]
        warn "Library: #{lib_path}"
        warn "Function: #{func_name}"
        warn "Arguments: #{arg_pairs.inspect}"
        warn "Return type: #{@options[:return_type]}"
      end

      if @options[:dry_run]
        dry_run_info(lib_path, func_name, arg_pairs)
      else
        execute_call(lib_path, func_name, arg_pairs)
      end
    rescue Error => e
      warn "Error: #{e.message}"
      exit 1
    rescue StandardError => e
      warn "Unexpected error: #{e.message}"
      warn e.backtrace if @options[:verbose]
      exit 1
    end

    private

    def parse_options_banner
      examples = if Platform.windows?
                   PLATFORM_EXAMPLES[:windows]
                 elsif Platform.darwin?
                   PLATFORM_EXAMPLES[:darwin]
                 else
                   PLATFORM_EXAMPLES[:unix]
                 end

      <<~BANNER
        Usage: libcall [OPTIONS] <LIBRARY> <FUNCTION> (TYPE VALUE)...

        Call C functions in shared libraries from the command line.

        Arguments are passed as TYPE VALUE pairs.

        Examples:
          #{examples.lines.map { |line| line.chomp }.join("\n  ")}

        Options:
          -l, --lib LIBRARY        Library name to search for (e.g., -lm for libm)
          -L, --lib-path PATH      Add directory to library search path
          -r, --ret TYPE           Return type (default: void)
              --dry-run            Show what would be executed without calling
              --json               Output result in JSON format
              --verbose            Show detailed information
          -h, --help               Show this help message
          -v, --version            Show version information
      BANNER
    end

    # Custom scanner that supports:
    # - Known flags anywhere (before/after function name)
    # - Negative numbers as values (not mistaken for options)
    # - TYPE VALUE pairs
    def scan_argv!(argv)
      lib_path = nil
      func_name = nil
      arg_pairs = []

      positional_only = false
      i = 0
      while i < argv.length
        tok = argv[i]

        # End-of-options marker: switch to positional-only mode
        if tok == '--'
          positional_only = true
          i += 1
          next
        end

        # Try to handle as a known option (only if not in positional-only mode)
        unless positional_only
          option_consumed = handle_option!(tok, argv, i)
          if option_consumed > 0
            i += option_consumed
            next
          end
        end

        # Positional resolution for <LIBRARY> and <FUNCTION>
        if lib_path.nil? && @options[:lib_name].nil?
          lib_path = tok
          i += 1
          next
        end

        if func_name.nil?
          func_name = tok
          i += 1
          next
        end

        # After function name: parse TYPE VALUE pairs (or TYPE-only for out:TYPE)
        type_tok = tok
        i += 1

        type_sym = Parser.parse_type(type_tok)

        # TYPE that represents an output pointer/array does not require a value
        if type_sym.is_a?(Array) && %i[out out_array].include?(type_sym.first)
          arg_pairs << [type_sym, nil]
          next
        end

        # Allow `--` between TYPE and VALUE to switch to positional-only
        while i < argv.length && argv[i] == '--'
          positional_only = true
          i += 1
        end

        raise Error, "Missing value for argument of type #{type_tok}" if i >= argv.length

        value_tok = argv[i]
        value = Parser.coerce_value(type_sym, value_tok)
        arg_pairs << [type_sym, value]
        i += 1
      end

      [lib_path, func_name, arg_pairs]
    end

    # Handle known option flags and return number of consumed tokens (0 if not an option)
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize
    def handle_option!(tok, argv, i)
      case tok
      when '--dry-run'
        @options[:dry_run] = true
        1
      when '--json'
        @options[:json] = true
        1
      when '--verbose'
        @options[:verbose] = true
        1
      when '-h', '--help'
        puts parse_options_banner
        exit 0
      when '-v', '--version'
        puts "libcall #{Libcall::VERSION}"
        exit 0
      when '-l', '--lib'
        raise Error, 'Missing value for -l/--lib' if i + 1 >= argv.length

        @options[:lib_name] = argv[i + 1]
        2
      when /\A-l(.+)\z/
        @options[:lib_name] = ::Regexp.last_match(1)
        1
      when '-L', '--lib-path'
        raise Error, 'Missing value for -L/--lib-path' if i + 1 >= argv.length

        @options[:lib_paths] << argv[i + 1]
        2
      when '-r', '--ret'
        raise Error, 'Missing value for -r/--ret' if i + 1 >= argv.length

        @options[:return_type] = Parser.parse_return_type(argv[i + 1])
        2
      when /\A-r(.+)\z/
        @options[:return_type] = Parser.parse_return_type(::Regexp.last_match(1))
        1
      else
        0 # Not an option
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize

    def dry_run_info(lib_path, func_name, arg_pairs)
      info = build_info_hash(lib_path, func_name, arg_pairs)

      if @options[:json]
        puts JSON.pretty_generate(info)
      else
        print_info(info)
      end
    end

    def build_info_hash(lib_path, func_name, arg_pairs)
      {
        library: lib_path,
        function: func_name,
        arguments: arg_pairs.map.with_index do |(type_sym, value), i|
          {
            index: i,
            type: type_sym.to_s,
            value: value
          }
        end,
        return_type: @options[:return_type].to_s
      }
    end

    def print_info(info)
      puts "Library:  #{info[:library]}"
      puts "Function: #{info[:function]}"
      puts "Return:   #{info[:return_type]}"
      return if info[:arguments].empty?

      puts 'Arguments:'
      info[:arguments].each do |arg|
        puts "  [#{arg[:index]}] #{arg[:type]} = #{arg[:value].inspect}"
      end
    end

    def execute_call(lib_path, func_name, arg_pairs)
      caller = Caller.new(
        lib_path,
        func_name,
        arg_pairs: arg_pairs,
        return_type: @options[:return_type]
      )

      result = caller.call
      output_result(lib_path, func_name, result)
    end

    def output_result(lib_path, func_name, result)
      if @options[:json]
        output = {
          library: lib_path,
          function: func_name,
          return_type: @options[:return_type].to_s
        }

        if result.is_a?(Hash) && result.key?(:outputs)
          output[:result] = result[:result]
          output[:outputs] = result[:outputs]
        else
          output[:result] = result
        end

        puts JSON.pretty_generate(output, allow_nan: true)
      elsif result.is_a?(Hash) && result.key?(:outputs)
        puts "Result: #{result[:result]}" unless result[:result].nil?
        unless result[:outputs].empty?
          puts 'Output parameters:'
          result[:outputs].each do |out|
            puts "  [#{out[:index]}] #{out[:type]} = #{out[:value]}"
          end
        end
      else
        puts result unless result.nil?
      end
    end
  end
end
