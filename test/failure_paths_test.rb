# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'libcall/library_finder'

class FailurePathsTest < Test::Unit::TestCase
  ROOT = File.expand_path('..', __dir__)
  LIBCALL = File.join(ROOT, 'exe', 'libcall')
  LIBM = if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
           'msvcrt.dll'
         elsif RUBY_PLATFORM =~ /darwin/
           '/usr/lib/libSystem.B.dylib'
         else
           '/lib/x86_64-linux-gnu/libm.so.6'
         end

  def run_libcall(*args)
    env = { 'RUBYLIB' => File.join(ROOT, 'lib') }
    stdout, stderr, status = Open3.capture3(env, 'ruby', LIBCALL, *args, chdir: ROOT)
    [stdout.strip, stderr.strip, status.success?]
  end

  def run_libcall_with_env(extra_env, *args)
    env = { 'RUBYLIB' => File.join(ROOT, 'lib') }
    env.merge!(extra_env)
    stdout, stderr, status = Open3.capture3(env, 'ruby', LIBCALL, *args, chdir: ROOT)
    [stdout.strip, stderr.strip, status.success?]
  end

  test 'LibraryFinder raises on non-existent library' do
    finder = Libcall::LibraryFinder.new
    err = assert_raise(Libcall::Error) { finder.find('_____no_such_lib_____') }
    assert_match(/Library not found/i, err.message)
  end

  test 'CLI fails on unknown argument type' do
    _stdout, stderr, success = run_libcall(LIBM, 'sqrt', 'zzz', '1', '-r', 'f64')
    assert_false success
    assert_match(/Unknown type/i, stderr)
  end

  test 'CLI fails on unknown return type' do
    _stdout, stderr, success = run_libcall(LIBM, 'sqrt', 'double', '9.0', '-r', 'zzz')
    assert_false success
    assert_match(/Unknown return type/i, stderr)
  end

  test 'pkg-config nonexistent package fails to resolve' do
    # Ensure PKG_CONFIG_PATH doesn't accidentally pick up test fixtures
    _stdout, stderr, success = run_libcall_with_env({ 'PKG_CONFIG_PATH' => '' }, '-lnonexistent_pkg_123456', 'sqrt',
                                                    'double', '9.0', '-r', 'f64')
    assert_false success
    assert_match(/Library not found/i, stderr)
  end
end
