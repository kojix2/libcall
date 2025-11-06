# frozen_string_literal: true

module Libcall
  # Platform detection utilities
  module Platform
    # Check if running on Windows
    def self.windows?
      RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    end

    # Check if running on macOS
    def self.darwin?
      RUBY_PLATFORM =~ /darwin/
    end

    # Check if running on Unix-like system (Linux, BSD, etc.)
    def self.unix?
      !windows?
    end

    # Get platform-specific library extensions
    def self.library_extensions
      if windows?
        ['', '.dll', '.so', '.a']
      elsif darwin?
        ['', '.dylib', '.so', '.a']
      else
        ['', '.so', '.a']
      end
    end

    # Get architecture string
    def self.architecture
      if RUBY_PLATFORM =~ /x86_64/
        'x86_64'
      elsif RUBY_PLATFORM =~ /aarch64|arm64/
        'aarch64'
      else
        'unknown'
      end
    end
  end
end
