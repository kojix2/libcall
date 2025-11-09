# frozen_string_literal: true

require_relative 'libcall/version'
require_relative 'libcall/parser'
require_relative 'libcall/library_finder'
require_relative 'libcall/callback_handler'
require_relative 'libcall/output_reader'
require_relative 'libcall/argument_processor'
require_relative 'libcall/caller'
require_relative 'libcall/cli'
require_relative 'libcall/fiddley'

module Libcall
  class Error < StandardError; end
end
