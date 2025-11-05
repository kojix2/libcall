# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'fileutils'

SO_EXT = RUBY_PLATFORM =~ /darwin/ ? 'dylib' : 'so'
CC = ENV['CC'] || 'gcc'

namespace :build do
  desc 'Build C test fixtures'
  task :fixtures do
    src_dir = File.join(__dir__, 'test', 'fixtures', 'libtest')
    build_dir = File.join(src_dir, 'build')
    FileUtils.mkdir_p(build_dir)

    src = File.join(src_dir, 'test_lib.c')
    out = File.join(build_dir, "libtest.#{SO_EXT}")
    pc_path = File.join(src_dir, 'libtest.pc')

    # Build shared library
    if SO_EXT == 'dylib'
      sh "#{CC} -dynamiclib -o #{out} #{src}"
    else
      sh "#{CC} -shared -fPIC -o #{out} #{src}"
    end

    # Generate pkg-config file
    File.write(pc_path, <<~PC)
      Name: libtest
      Description: Test fixture library for libcall
      Version: 1.0
      Libs: -L#{build_dir} -ltest
      Cflags:
    PC
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task test: 'build:fixtures'
task default: :test
