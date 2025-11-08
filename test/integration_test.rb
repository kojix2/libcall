# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'open3'

class IntegrationTest < Test::Unit::TestCase
  ROOT = File.expand_path('..', __dir__)
  LIBCALL = File.join(ROOT, 'exe', 'libcall')
  LIBM = if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
           # Windows: use msvcrt.dll for math functions
           'msvcrt.dll'
         elsif RUBY_PLATFORM =~ /darwin/
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

  def run_libcall_with_env(extra_env, *args)
    env = { 'RUBYLIB' => File.join(ROOT, 'lib') }
    # Allow caller to explicitly control pkg-config visibility
    env['PKG_CONFIG_PATH'] = ENV['PKG_CONFIG_PATH'] if ENV['PKG_CONFIG_PATH']
    env.merge!(extra_env)
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
    if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      File.join(ROOT, 'test', 'fixtures', 'libtest', 'build', 'libtest.dll')
    elsif RUBY_PLATFORM =~ /darwin/
      File.join(ROOT, 'test', 'fixtures', 'libtest', 'build', 'libtest.dylib')
    else
      File.join(ROOT, 'test', 'fixtures', 'libtest', 'build', 'libtest.so')
    end
  end

  def fixture_lib_available?
    File.exist?(fixture_lib_path)
  end

  test 'calling sqrt function' do
    stdout, stderr, success = run_libcall(LIBM, 'sqrt', 'double', '16.0', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '4.0', stdout
  end

  test 'calling cos function' do
    stdout, stderr, success = run_libcall(LIBM, 'cos', 'double', '0.0', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '1.0', stdout
  end

  test 'dry run mode' do
    stdout, stderr, success = run_libcall('--dry-run', LIBM, 'sqrt', 'double', '25.0', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_match(/Library:/, stdout)
    assert_match(/sqrt/, stdout)
    assert_match(/25\.0/, stdout)
  end

  test 'json output' do
    stdout, stderr, success = run_libcall('--json', LIBM, 'sqrt', 'double', '9.0', '-r', 'f64')
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
    omit('skipping -lm test on Windows; use msvcrt.dll directly') if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    omit('libm is not a standalone library on macOS; use full path tests instead') if RUBY_PLATFORM =~ /darwin/
    stdout, stderr, success = run_libcall('-lm', 'sqrt', 'double', '16.0', '-r', 'f64')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '4.0', stdout
  end

  test 'library search with -L flag' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'), 'add_i32',
                                          'int', '10', 'int', '20', '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '30', stdout
  end

  test 'out parameters: get_version writes two ints' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'get_version', 'out:int', 'out:int', '-r', 'void')
    assert success, "Command should succeed: #{stderr}"
    # Human-readable output should list output parameters
    assert_match(/Output parameters:/, stdout)
    assert_match(/\[0\] int = 1/, stdout)
    assert_match(/\[1\] int = 2/, stdout)
  end

  test 'out parameters with json output' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('--json', '-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'get_version', 'out:int', 'out:int', '-r', 'void')
    assert success, "Command should succeed: #{stderr}"
    doc = JSON.parse(stdout)
    assert_equal 'void', doc['return_type']
    assert_kind_of Array, doc['outputs']
    assert_equal({ 'index' => 0, 'type' => 'int', 'value' => 1 }, doc['outputs'][0])
    assert_equal({ 'index' => 1, 'type' => 'int', 'value' => 2 }, doc['outputs'][1])
  end

  test 'out:string returns C-allocated string through char**' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'out_echo_string', 'string', '"hello"', 'out:string', '-r', 'void')
    assert success, "Command should succeed: #{stderr}"
    assert_match(/Output parameters:/, stdout)
    assert_match(/\[1\] string = hello/, stdout)
  end

  test 'out:string with json output' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('--json', '-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'out_echo_string', 'string', '"world"', 'out:string', '-r', 'void')
    assert success, "Command should succeed: #{stderr}"
    doc = JSON.parse(stdout)
    assert_equal 'void', doc['return_type']
    assert_kind_of Array, doc['outputs']
    assert_equal({ 'index' => 1, 'type' => 'string', 'value' => 'world' }, doc['outputs'][0])
  end

  test 'pair format: add_i32 with negative int value and -r after function' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'), 'add_i32',
                                          'int', '32', 'int', '-23', '-r', 'int')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '9', stdout
  end

  test 'pair format: fabs with negative double' do
    if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      stdout, stderr, success = run_libcall('-r', 'f64', 'msvcrt.dll', 'fabs', 'double', '-5.5')
    elsif RUBY_PLATFORM =~ /darwin/
      stdout, stderr, success = run_libcall('-r', 'f64', LIBM, 'fabs', 'double', '-5.5')
    else
      stdout, stderr, success = run_libcall('-lm', '-r', 'f64', 'fabs', 'double', '-5.5')
    end
    assert success, "Command should succeed: #{stderr}"
    assert_equal '5.5', stdout
  end

  test 'null pointer argument to str_length returns 0' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    lib = fixture_lib_path
    stdout, stderr, success = run_libcall(lib, 'str_length', 'ptr', 'null', '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '0', stdout
  end

  test 'cstr return from libc getenv' do
    if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      stdout, stderr, success = run_libcall('msvcrt.dll', 'getenv', 'string', '"PATH"', '-r', 'cstr')
    elsif RUBY_PLATFORM =~ /darwin/
      stdout, stderr, success = run_libcall('/usr/lib/libSystem.B.dylib', 'getenv', 'string', '"PATH"', '-r', 'cstr')
    else
      stdout, stderr, success = run_libcall('-lc', 'getenv', 'string', '"PATH"', '-r', 'cstr')
    end
    assert success, "Command should succeed: #{stderr}"
    assert(!stdout.empty?, 'PATH should not be empty')
  end

  test "'--' stops option parsing so string value '-r' is allowed" do
    # Place return type before '--' because anything after is positional-only
    if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      stdout, stderr, success = run_libcall('-r', 'cstr', 'msvcrt.dll', 'getenv', 'string', '--', '-r')
    elsif RUBY_PLATFORM =~ /darwin/
      stdout, stderr, success = run_libcall('-r', 'cstr', LIBM, 'getenv', 'string', '--', '-r')
    else
      stdout, stderr, success = run_libcall('-r', 'cstr', '-lc', 'getenv', 'string', '--', '-r')
    end
    assert success, "Command should succeed: #{stderr}"
    # getenv('-r') is expected to be unset; cstr formatter prints (null)
    assert_equal '(null)', stdout
  end

  test 'pkg-config package name via -l resolves library' do
    omit('pkg-config binary or package not available in environment') unless pkg_config_available?('libtest')
    omit('fixture shared library is not available') unless fixture_lib_available?
    # Here -llibtest indicates the package name; LibraryFinder uses pkg-config
    stdout, stderr, success = run_libcall('-llibtest', 'add_i32', 'int', '10', 'int', '20', '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '30', stdout
  end

  test 'input array: sum_i32_array with int[] and length' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'sum_i32_array', 'int[]', '1,2,3,4,5', 'size_t', '5', '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '15', stdout
  end

  test 'output array: fill_seq_i32 into out:int[5]' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'fill_seq_i32', 'out:int[5]', 'size_t', '5', '-r', 'void')
    assert success, "Command should succeed: #{stderr}"
    assert_match(/Output parameters:/, stdout)
    # Expect array values 0..4
    assert_match(/\[0\] int\[5\] = \[0, 1, 2, 3, 4\]/, stdout)
  end

  test 'callback argument: apply_i32 with addition proc' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'apply_i32', 'int', '3', 'int', '5', 'func', "'int(int,int){|a,b| a+b}'", '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '8', stdout
  end

  test 'callback alias keyword: apply_i32 with subtraction proc' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    stdout, stderr, success = run_libcall('-ltest', '-L', File.join('test', 'fixtures', 'libtest', 'build'),
                                          'apply_i32', 'int', '10', 'int', '3', 'callback', "'int(int,int){|a,b| a-b}'", '-r', 'i32')
    assert success, "Command should succeed: #{stderr}"
    assert_equal '7', stdout
  end

  test 'qsort via libc with callback DSL prints sorted out array' do
    omit('libc path differs on this platform') if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    libc = if RUBY_PLATFORM =~ /darwin/
             '/usr/lib/libSystem.B.dylib'
           else
             '/lib/x86_64-linux-gnu/libc.so.6'
           end
    stdout, stderr, success = run_libcall(libc, 'qsort',
                                          'out:int[4]', '4,2,3,1',
                                          'size_t', '4',
                                          'size_t', '4',
                                          'callback', "'int(void*,void*){|pa,pb| int(pa) <=> int(pb) }'",
                                          '-r', 'void')
    assert success, "Command should succeed: #{stderr}"
    assert_match(/Output parameters:/, stdout)
    assert_match(/int\[4\] = \[1, 2, 3, 4\]/, stdout)
  end

  test 'library search via env var (LD_LIBRARY_PATH/DYLD_LIBRARY_PATH)' do
    omit('fixture shared library is not available') unless fixture_lib_available?
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      # Copy the built fixture library into a temp directory
      FileUtils.cp(fixture_lib_path, File.join(dir, File.basename(fixture_lib_path)))

      if RUBY_PLATFORM =~ /darwin/
        env = { 'DYLD_LIBRARY_PATH' => dir, 'PKG_CONFIG_PATH' => '' }
      elsif RUBY_PLATFORM =~ /mswin|mingw|cygwin/
        omit('LD_LIBRARY_PATH/DYLD_LIBRARY_PATH not applicable on Windows')
      else
        env = { 'LD_LIBRARY_PATH' => dir, 'PKG_CONFIG_PATH' => '' }
      end

      stdout, stderr, success = run_libcall_with_env(env, '-ltest', 'add_i32', 'int', '10', 'int', '20', '-r', 'i32')
      assert success, "Command should succeed: #{stderr}"
      assert_equal '30', stdout
    end
  end
end
