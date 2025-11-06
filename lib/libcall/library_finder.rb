# frozen_string_literal: true

require 'fiddle'
require_relative 'platform'

begin
  require 'pkg-config'
rescue LoadError
  # pkg-config is optional
end

module Libcall
  # Find shared libraries by name using standard search paths and pkg-config
  class LibraryFinder
    def initialize(lib_paths: [])
      @lib_paths = lib_paths
      @default_paths = default_library_paths
    end

    # Find library by name (e.g., "m" -> "/lib/x86_64-linux-gnu/libm.so.6")
    def find(lib_name)
      # If it's a path, return as-is
      return File.expand_path(lib_name) if path_like?(lib_name)

      search_paths = @lib_paths + @default_paths

      if defined?(PKGConfig)
        pkg_exists = begin
          PKGConfig.public_send(
            PKGConfig.respond_to?(:exist?) ? :exist? : :have_package,
            lib_name
          )
        rescue StandardError
          false
        end

        if pkg_exists
          lib_dirs = extract_pkg_config_flags(lib_name, 'L')
          lib_names = extract_pkg_config_flags(lib_name, 'l')

          search_paths = lib_dirs + search_paths

          # Attempt to resolve any of the advertised libs from the package
          lib_names.each do |lname|
            resolved = resolve_by_name_in_paths(lname, search_paths)
            return resolved if resolved
          end
        end
      end

      # Try resolving the provided name using standard conventions
      resolved = resolve_by_name_in_paths(lib_name, search_paths)
      return resolved if resolved

      raise Error, "Library not found: #{lib_name} (searched in: #{search_paths.join(', ')})"
    end

    private

    def path_like?(name)
      name.include?('/') || name.include?('\\') || File.file?(name)
    end

    # Extract -L or -l flags from pkg-config output, normalized without the dash prefix
    def extract_pkg_config_flags(lib_name, flag_char)
      base = if flag_char == 'L' && PKGConfig.respond_to?(:libs_only_L)
               PKGConfig.libs_only_L(lib_name)
             elsif flag_char == 'l' && PKGConfig.respond_to?(:libs_only_l)
               PKGConfig.libs_only_l(lib_name)
             else
               PKGConfig.libs(lib_name)
             end

      base.to_s.split
          .select { |t| t.start_with?("-#{flag_char}") }
          .map { |t| t[2..] }
    end

    def default_library_paths
      (Platform.windows? ? windows_library_paths : unix_library_paths)
        .select { |p| Dir.exist?(p) }
    end

    def windows_library_paths
      paths = %w[C:/Windows/System32 C:/Windows/SysWOW64]

      # MSYS2/MinGW paths
      if ENV['MSYSTEM']
        msys_prefix = ENV['MINGW_PREFIX'] || 'C:/msys64/mingw64'
        paths.concat(["#{msys_prefix}/bin", "#{msys_prefix}/lib"])
      end

      # Add PATH directories on Windows
      if ENV['PATH']
        paths.concat(ENV['PATH'].split(';').map { |p| p.tr('\\', '/') })
      end

      paths
    end

    def unix_library_paths
      # Standard library paths
      paths = %w[/lib /usr/lib /usr/local/lib]

      # Architecture-specific paths (Linux)
      case Platform.architecture
      when 'x86_64'
        paths.concat(%w[/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu])
      when 'aarch64'
        paths.concat(%w[/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu])
      end

      # macOS paths
      paths.concat(%w[/usr/local/lib /opt/homebrew/lib]) if Platform.darwin?

      # Environment-based paths
      paths.concat(ENV.fetch('LD_LIBRARY_PATH', '').split(':'))
      paths.concat(ENV.fetch('DYLD_LIBRARY_PATH', '').split(':'))

      paths
    end

    def resolve_by_name_in_paths(lib_name, search_paths)
      # Try direct name first (e.g., "libm.so")
      search_paths.each do |path|
        full_path = File.join(path, lib_name)
        return File.expand_path(full_path) if File.file?(full_path)
      end

      # Try with lib prefix and common extensions
      prefixes = lib_name.start_with?('lib') ? [''] : ['lib', '']
      extensions = Platform.library_extensions

      prefixes.product(extensions, search_paths).each do |prefix, ext, path|
        name = "#{prefix}#{lib_name}#{ext}"
        full_path = File.join(path, name)
        return File.expand_path(full_path) if File.file?(full_path)

        # Check for versioned libraries (libm.so.6, etc.)
        next if ext.empty?

        matches = Dir.glob(File.join(path, "#{name}.*")).select { |f| File.file?(f) }
        return File.expand_path(matches.first) unless matches.empty?
      end

      nil
    end
  end
end
