# frozen_string_literal: true

require_relative 'libcall/version'
require_relative 'libcall/parser'
require_relative 'libcall/library_finder'
require_relative 'libcall/caller'
require_relative 'libcall/cli'

module Libcall
  class Error < StandardError; end
end
