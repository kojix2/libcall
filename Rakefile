# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'fileutils'

IS_WINDOWS = RUBY_PLATFORM =~ /mswin|mingw|cygwin/
SO_EXT = if IS_WINDOWS
           'dll'
         elsif RUBY_PLATFORM =~ /darwin/
           'dylib'
         else
           'so'
         end
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
    compile_cmd = if SO_EXT == 'dylib'
                    "#{CC} -dynamiclib -o #{out} #{src}"
                  elsif SO_EXT == 'dll'
                    "#{CC} -shared -o #{out} #{src}"
                  else
                    "#{CC} -shared -fPIC -o #{out} #{src}"
                  end

    # On Windows, prefer RubyInstaller's DevKit via ridk if available
    if IS_WINDOWS && system('where ridk >NUL 2>&1')
      sh "ridk exec #{compile_cmd}"
    else
      sh compile_cmd
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
