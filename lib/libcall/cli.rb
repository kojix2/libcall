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
      parse_options!

      if @argv.empty?
        puts @parser.help
        exit 1
      end

      # Resolve library path
      if @options[:lib_name]
        finder = LibraryFinder.new(lib_paths: @options[:lib_paths])
        lib_path = finder.find(@options[:lib_name])
      else
        lib_path = @options[:lib] || @argv.shift
      end

      func_name = @argv.shift
      args = @argv

      if lib_path.nil? || func_name.nil?
        warn 'Error: Missing required arguments'
        warn 'Usage: libcall <LIBRARY> <FUNCTION> [ARGS...]'
        exit 1
      end

      if @options[:verbose]
        warn "Library: #{lib_path}"
        warn "Function: #{func_name}"
        warn "Arguments: #{args.inspect}"
        warn "Return type: #{@options[:return_type]}"
      end

      if @options[:dry_run]
        dry_run_info(lib_path, func_name, args)
      else
        execute_call(lib_path, func_name, args)
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

    def parse_options!
      @parser = OptionParser.new do |opts|
        opts.banner = <<~BANNER
          Usage: libcall [OPTIONS] <LIBRARY> <FUNCTION> [ARGS...]

          Call C functions in shared libraries from the command line.

          Examples:
            libcall /lib/libm.so.6 sqrt 16.0f64 -r f64
            libcall -lm sqrt 16.0f64 -r f64
            libcall -lsum -L. add 10i32 20i32 -r i32
            libcall --dry-run ./mylib.so test 42u64 -r void

          Options:
        BANNER

        opts.on('--dry-run', 'Validate arguments without executing') do
          @options[:dry_run] = true
        end

        opts.on('--json', 'Output result as JSON') do
          @options[:json] = true
        end

        opts.on('--verbose', 'Show detailed information') do
          @options[:verbose] = true
        end

        opts.on('-l', '--lib LIBRARY', 'Library name (searches in standard paths)') do |lib|
          @options[:lib_name] = lib
        end

        opts.on('-L', '--lib-path PATH', 'Add library search path') do |path|
          @options[:lib_paths] << path
        end

        opts.on('-r', '--ret TYPE', 'Return type (void, i32, f64, cstr, etc.)') do |type|
          @options[:return_type] = Parser.parse_return_type(type)
        end

        opts.on('-h', '--help', 'Show help') do
          puts opts
          exit
        end

        opts.on('-v', '--version', 'Show version') do
          puts "libcall #{Libcall::VERSION}"
          exit
        end
      end

      @parser.permute!(@argv)
    end

    def dry_run_info(lib_path, func_name, args)
      info = {
        library: lib_path,
        function: func_name,
        arguments: [],
        return_type: @options[:return_type].to_s
      }

      args.each_with_index do |arg, i|
        type_sym, value = Parser.parse_arg(arg)
        info[:arguments] << {
          index: i,
          raw: arg,
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
            puts "  [#{arg[:index]}] #{arg[:raw]} => #{arg[:type]} (#{arg[:value].inspect})"
          end
        end
      end
    end

    def execute_call(lib_path, func_name, args)
      caller = Caller.new(
        lib_path,
        func_name,
        args: args,
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
