# frozen_string_literal: true

require 'optparse'
require 'json'

module Libcall
  class CLI
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
        warn 'Usage: libcall [OPTIONS] <LIBRARY> <FUNCTION> [(TYPE VALUE) | ARG]...'
        exit 1
      end

      if @options[:verbose]
        warn "Library: #{lib_path}"
        warn "Function: #{func_name}"
        warn "Arguments: #{args.inspect}"
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
      <<~BANNER
        Usage: libcall [OPTIONS] <LIBRARY> <FUNCTION> (TYPE VALUE)...

        Call C functions in shared libraries from the command line.

        Pass arguments as TYPE VALUE pairs only.

        Examples:
          libcall -lm -r f64 sqrt double 16
          libcall -ltest -L ./build add_i32 int 10 int -23 -r int
          libcall --dry-run ./mylib.so test 42u64 -r void

        Options:
      BANNER
    end

    # Custom scanner that supports:
    # - Known flags anywhere (before/after function name)
    # - Negative numbers as values (not mistaken for options)
    # - TYPE VALUE pairs and legacy single-token args mixed
    def scan_argv!(argv)
      lib_path = nil
      func_name = nil
      arg_pairs = []

      i = 0
      while i < argv.length
        tok = argv[i]

        # End-of-options marker: everything that follows becomes a raw arg token
        if tok == '--'
          i += 1
          while i < argv.length
            args_tokens << argv[i]
            i += 1
          end
          break
        end

        # Global flags (allowed anywhere)
        case tok
        when '--dry-run'
          @options[:dry_run] = true
          i += 1
          next
        when '--json'
          @options[:json] = true
          i += 1
          next
        when '--verbose'
          @options[:verbose] = true
          i += 1
          next
        when '-h', '--help'
          puts parse_options_banner
          exit 0
        when '-v', '--version'
          puts "libcall #{Libcall::VERSION}"
          exit 0
        when '-l', '--lib'
          i += 1
          raise Error, 'Missing value for -l/--lib' if i >= argv.length

          @options[:lib_name] = argv[i]
          i += 1
          next
        when /\A-l(.+)\z/
          @options[:lib_name] = ::Regexp.last_match(1)
          i += 1
          next
        when '-L', '--lib-path'
          i += 1
          raise Error, 'Missing value for -L/--lib-path' if i >= argv.length

          @options[:lib_paths] << argv[i]
          i += 1
          next
        when '-r', '--ret'
          i += 1
          raise Error, 'Missing value for -r/--ret' if i >= argv.length

          @options[:return_type] = Parser.parse_return_type(argv[i])
          i += 1
          next
        when /\A-r(.+)\z/
          @options[:return_type] = Parser.parse_return_type(::Regexp.last_match(1))
          i += 1
          next
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

        # After function name: parse TYPE VALUE pairs, allowing options anywhere
        type_tok = tok
        i += 1
        raise Error, "Missing value for argument of type #{type_tok}" if i >= argv.length

        value_tok = argv[i]
        type_sym = Parser.parse_type(type_tok)
        value = Parser.coerce_value(type_sym, value_tok)
        arg_pairs << [type_sym, value]
        i += 1
      end

      [lib_path, func_name, arg_pairs]
    end

    def dry_run_info(lib_path, func_name, arg_pairs)
      info = {
        library: lib_path,
        function: func_name,
        arguments: [],
        return_type: @options[:return_type].to_s
      }

      arg_pairs.each_with_index do |(type_sym, value), i|
        info[:arguments] << {
          index: i,
          type: type_sym.to_s,
          value: value
        }
      end

      if @options[:json]
        puts JSON.pretty_generate(info)
      else
        puts "Library:  #{info[:library]}"
        puts "Function: #{info[:function]}"
        puts "Return:   #{info[:return_type]}"
        unless info[:arguments].empty?
          puts 'Arguments:'
          info[:arguments].each do |arg|
            puts "  [#{arg[:index]}] #{arg[:type]} = #{arg[:value].inspect}"
          end
        end
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

      if @options[:json]
        output = {
          library: lib_path,
          function: func_name,
          return_type: @options[:return_type].to_s,
          result: result
        }
        puts JSON.pretty_generate(output, allow_nan: true)
      else
        puts result unless result.nil?
      end
    end
  end
end
