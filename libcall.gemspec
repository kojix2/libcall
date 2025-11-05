# frozen_string_literal: true

require_relative 'lib/libcall/version'

Gem::Specification.new do |spec|
  spec.name          = 'libcall'
  spec.version       = Libcall::VERSION
  spec.summary       = 'Call functions in shared libraries directly from the CLI'
  spec.homepage      = 'https://github.com/kojix2/libcall'
  spec.license       = 'MIT'

  spec.author        = 'kojix2'
  spec.email         = '2xijok@gmail.com'

  spec.files         = Dir['*.{md,txt}', '{exe,lib}/**/*']
  spec.require_path  = 'lib'
  spec.bindir        = 'exe'
  spec.executables   = ['libcall']

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'fiddle'
  spec.add_dependency 'pkg-config'
end
