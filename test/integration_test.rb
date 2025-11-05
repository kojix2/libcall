# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'open3'

class IntegrationTest < Test::Unit::TestCase
  ROOT = File.expand_path('..', __dir__)
  LIBCALL = File.join(ROOT, 'exe', 'libcall')
  LIBM = if RUBY_PLATFORM =~ /darwin/
           '/usr/lib/libSystem.B.dylib'
         else
           '/lib/x86_64-linux-gnu/libm.so.6'
         end

  def run_libcall(*args)
    env = { 'RUBYLIB' => File.join(ROOT, 'lib') }
    env['PKG_CONFIG_PATH'] = ENV['PKG_CONFIG_PATH'] if ENV['PKG_CONFIG_PATH']
    stdout, stderr, status = Open3.capture3(env, 'ruby', LIBCALL, *args, chdir: ROOT)
    [stdout.strip, stderr.strip, status.success?]
  end

  def pkg_config_available?(pkg)
    begin
      require 'pkg-config'
    rescue LoadError
      return false
    end
    ENV['PKG_CONFIG_PATH'] = File.join(ROOT, 'test', 'fixtures', 'libtest')
    if PKGConfig.respond_to?(:exist?)
      PKGConfig.exist?(pkg)
    elsif PKGConfig.respond_to?(:have_package)
      PKGConfig.have_package(pkg)
    else
      false
    end
  end

  def fixture_lib_path
    if RUBY_PLATFORM =~ /darwin/
      File.join(ROOT, 'test', 'fixtures', 'libtest', 'build', 'libtest.dylib')
    else
      File.join(ROOT, 'test', 'fixtures', 'libtest', 'build', 'libtest.so')
    end
  end

  def fixture_lib_available?
    File.exist?(fixture_lib_path)
  end

  test 'calling sqrt function' do
    stdout, stderr, success = run_libcall(LIBM, 'sqrt', '16.0f64', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '4.0', stdout
  end

  test 'calling cos function' do
    stdout, stderr, success = run_libcall(LIBM, 'cos', '0.0f64', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '1.0', stdout
  end

  test 'dry run mode' do
    stdout, stderr, success = run_libcall('--dry-run', LIBM, 'sqrt', '25.0f64', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_match(/Library:/, stdout)
    assert_match(/sqrt/, stdout)
    assert_match(/25\.0/, stdout)
  end

  test 'json output' do
    stdout, stderr, success = run_libcall('--json', LIBM, 'sqrt', '9.0f64', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"

    result = JSON.parse(stdout)
    assert_equal LIBM, result['library']
    assert_equal 'sqrt', result['function']
    assert_equal 'double', result['return_type']
    assert_equal 3.0, result['result']
  end

  test 'version flag' do
    env = { 'RUBYLIB' => File.join(ROOT, 'lib') }
    stdout, _stderr, status = Open3.capture3(env, 'ruby', LIBCALL, '--version', chdir: ROOT)
    assert status.success?
    assert_match(/libcall/, stdout)
    assert_match(/\d+\.\d+\.\d+/, stdout)
  end

  test 'help flag' do
    env = { 'RUBYLIB' => File.join(ROOT, 'lib') }
    stdout, _stderr, status = Open3.capture3(env, 'ruby', LIBCALL, '--help', chdir: ROOT)
    assert status.success?
    assert_match(/Usage:/, stdout)
    assert_match(/Options:/, stdout)
    assert_match(/shared libraries/, stdout)
  end

  test 'library search with -l flag' do
    omit('libm is not a standalone library on macOS; use full path tests instead') if RUBY_PLATFORM =~ /darwin/
    stdout, stderr, success = run_libcall('-lm', 'sqrt', '16.0f64', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '4.0', stdout
  end

  test 'library search with -L flag' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'), 'add_i32',
                                          '10i32', '20i32', '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '30', stdout
  end

  test 'cstr return from libc getenv' do
    if RUBY_PLATFORM =~ /darwin/
      stdout, stderr, success = run_libcall('/usr/lib/libSystem.B.dylib', 'getenv', '"PATH"', '-r', 'cstr')
    else
      stdout, stderr, success = run_libcall('-lc', 'getenv', '"PATH"', '-r', 'cstr')
    end
    assert success, "Command should succeed: #{stderr}"
    assert(!stdout.empty?, 'PATH should not be empty')
  end

  test 'negative float argument with -- separator and -r before it' do
    if RUBY_PLATFORM =~ /darwin/
      stdout, stderr, success = run_libcall('-r', 'f64', LIBM, 'fabs', '--', '-5.5f64')
    else
      stdout, stderr, success = run_libcall('-lm', '-r', 'f64', 'fabs', '--', '-5.5f64')
    end
    assert success, "Command should succeed: #{stderr}"
    assert_equal '5.5', stdout
  end

  test 'pkg-config package name via -l resolves library' do
    omit('pkg-config binary or package not available in environment') unless pkg_config_available?('libtest')
    omit('fixture shared library is not available') unless fixture_lib_available?
    # Here -llibtest indicates the package name; LibraryFinder uses pkg-config
    stdout, stderr, success = run_libcall('-llibtest', 'add_i32', '10i32', '20i32', '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '30', stdout
  end
end
