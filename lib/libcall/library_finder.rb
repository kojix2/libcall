# frozen_string_literal: true

require 'fiddle'

begin
  require 'pkg-config'
rescue LoadError
  # pkg-config is optional
end

module Libcall
  class LibraryFinder
    def initialize(lib_paths: [])
      @lib_paths = lib_paths
      @default_paths = default_library_paths
    end

    # Find library by name (e.g., "m" -> "/lib/x86_64-linux-gnu/libm.so.6")
    def find(lib_name)
      # If it's a path, return as-is
      return File.expand_path(lib_name) if lib_name.include?('/') || lib_name.include?('\\')
      return File.expand_path(lib_name) if File.file?(lib_name)

      search_paths = @lib_paths + @default_paths

      if defined?(PKGConfig)
        pkg_exists = if PKGConfig.respond_to?(:exist?)
                       PKGConfig.exist?(lib_name)
                     else
                       PKGConfig.respond_to?(:have_package) ? PKGConfig.have_package(lib_name) : false
                     end

        if pkg_exists
          lib_dirs = if PKGConfig.respond_to?(:libs_only_L)
                       PKGConfig.libs_only_L(lib_name).to_s.split.map { |p| p.start_with?('-L') ? p[2..] : p }
                     else
                       PKGConfig.libs(lib_name).to_s.split.select { |t| t.start_with?('-L') }.map { |t| t[2..] }
                     end
          lib_names = if PKGConfig.respond_to?(:libs_only_l)
                        PKGConfig.libs_only_l(lib_name).to_s.split.map { |l| l.start_with?('-l') ? l[2..] : l }
                      else
                        PKGConfig.libs(lib_name).to_s.split.select { |t| t.start_with?('-l') }.map { |t| t[2..] }
                      end

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

    def default_library_paths
      paths = []

      if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
        # Windows paths
        paths << 'C:/Windows/System32'
        paths << 'C:/Windows/SysWOW64'

        # MSYS2/MinGW paths
        if ENV['MSYSTEM']
          msys_prefix = ENV['MINGW_PREFIX'] || 'C:/msys64/mingw64'
          paths << "#{msys_prefix}/bin"
          paths << "#{msys_prefix}/lib"
        end

        # Add PATH directories on Windows
        paths.concat(ENV['PATH'].split(';').map { |p| p.tr('\\', '/') }) if ENV['PATH']
      else
        # Unix-like systems (Linux, macOS)
        # Standard library paths
        paths << '/lib'
        paths << '/usr/lib'
        paths << '/usr/local/lib'

        # Architecture-specific paths
        if RUBY_PLATFORM =~ /x86_64/
          paths << '/lib/x86_64-linux-gnu'
          paths << '/usr/lib/x86_64-linux-gnu'
        elsif RUBY_PLATFORM =~ /aarch64|arm64/
          paths << '/lib/aarch64-linux-gnu'
          paths << '/usr/lib/aarch64-linux-gnu'
        end

        # macOS paths
        if RUBY_PLATFORM =~ /darwin/
          paths << '/usr/local/lib'
          paths << '/opt/homebrew/lib'
        end

        # LD_LIBRARY_PATH
        paths.concat(ENV['LD_LIBRARY_PATH'].split(':')) if ENV['LD_LIBRARY_PATH']

        # DYLD_LIBRARY_PATH (macOS)
        paths.concat(ENV['DYLD_LIBRARY_PATH'].split(':')) if ENV['DYLD_LIBRARY_PATH']
      end

      paths.select { |p| Dir.exist?(p) }
    end

    def resolve_by_name_in_paths(lib_name, search_paths)
      # Try direct name first (e.g., "libm.so")
      search_paths.each do |path|
        full_path = File.join(path, lib_name)
        return File.expand_path(full_path) if File.file?(full_path)
      end

      # Try with lib prefix and common extensions
      extensions = if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
                     ['', '.dll', '.so', '.a']
                   elsif RUBY_PLATFORM =~ /darwin/
                     ['', '.dylib', '.so', '.a']
                   else
                     ['', '.so', '.a']
                   end

      prefixes = lib_name.start_with?('lib') ? [''] : ['lib', '']

      prefixes.each do |prefix|
        extensions.each do |ext|
          name = "#{prefix}#{lib_name}#{ext}"
          search_paths.each do |path|
            full_path = File.join(path, name)
            return File.expand_path(full_path) if File.file?(full_path)

            # Check for versioned libraries (libm.so.6, etc.)
            next if ext.empty?

            pattern = File.join(path, "#{name}.*")
            matches = Dir.glob(pattern).select { |f| File.file?(f) }
            return File.expand_path(matches.first) unless matches.empty?
          end
        end
      end

      nil
    end
  end
end
