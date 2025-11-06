# libcall

[![test](https://github.com/kojix2/libcall/actions/workflows/main.yml/badge.svg)](https://github.com/kojix2/libcall/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/libcall.svg)](https://badge.fury.io/rb/libcall)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Flibcall%2Flines)](https://tokei.kojix2.net/github/kojix2/libcall)

Call C functions in shared libraries from the command line.

## Installation

```sh
gem install libcall
```

**Windows**: Supports DLLs (e.g., `msvcrt.dll`, `kernel32.dll`). Searches in System32, PATH, and MSYS2/MinGW directories. For building custom DLLs, RubyInstaller with DevKit is recommended.

## Usage

```sh
libcall [OPTIONS] <LIBRARY> <FUNCTION> (TYPE VALUE)...
```

### Quick Examples

```sh
# TYPE VALUE pairs
libcall -lm -r f64 sqrt double 16
# => 4.0

# Custom library
libcall ./mylib.so add_i32 int 10 int 20 -r i32
# => 30
```

### Argument Syntax

Pass arguments as TYPE VALUE pairs (single-token suffix style has been removed):

- Examples: `int 10`, `double -3.14`, `string "hello"`
- Negative values are safe (not treated as options): `int -23`

Pointers and null:

- Use `ptr` (or `pointer`) to pass raw addresses as integers
- Use `null`, `nil`, `NULL`, or `0` to pass a null pointer

```sh
# Pass a null pointer to a function taking const char*
libcall -ltest str_length ptr null -r i32
# => 0
```

End of options `--`:

- Use `--` to stop option parsing if a value starts with `-`

```sh
libcall -lc getenv string -- -r -r cstr
```

### Options

- `-l LIBRARY` - library name (searches standard paths)
- `-L PATH` - add library search path
- `-r TYPE` - return type (void, i32, f64, cstr, ptr)
- Options may appear before or after the function name.
- `--dry-run` - validate without executing
- `--json` - JSON output
- `--verbose` - detailed info
- `-h, --help` - show help
- `-v, --version` - show version

Library search:

- `-L` adds search paths; `-l` resolves by name
- On Linux and macOS, `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH` are honored

### More Examples

```sh
# JSON output
libcall --json -lm sqrt double 9.0 -r f64

# Dry run
libcall --dry-run ./mylib.so test u64 42 -r void

# Using -L and -l (like gcc)
libcall -lmylib -L./build add_i32 int 10 int 20 -r i32

# TYPE/VALUE pairs with -r after function
libcall -lm fabs double -5.5 -r f64
# => 5.5

# Windows: calling C runtime functions
libcall msvcrt.dll sqrt double 16.0 -r f64
# => 4.0

# Windows: accessing environment variables
libcall msvcrt.dll getenv string "PATH" -r cstr
```

## Type Reference

| Suffix | Type            | Range/Note         |
| ------ | --------------- | ------------------ |
| `i8`   | signed 8-bit    | -128 to 127        |
| `u8`   | unsigned 8-bit  | 0 to 255           |
| `i16`  | signed 16-bit   | -32768 to 32767    |
| `u16`  | unsigned 16-bit | 0 to 65535         |
| `i32`  | signed 32-bit   | standard int       |
| `u32`  | unsigned 32-bit | unsigned int       |
| `i64`  | signed 64-bit   | long long          |
| `u64`  | unsigned 64-bit | unsigned long long |
| `f32`  | 32-bit float    | single precision   |
| `f64`  | 64-bit float    | double precision   |

Also supported:

- `string`: C string argument (char*)
- `cstr`: C string return (char*)
- `ptr`/`pointer`: void* pointer

## pkg-config Support

Set `PKG_CONFIG_PATH` and use package names with `-l`:

```sh
PKG_CONFIG_PATH=/path/to/pkgconfig libcall -lmypackage func i32 42 -r i32
```

## Output parameters (out:TYPE)

You can pass output pointers by specifying `out:TYPE`. The pointer is allocated automatically, passed to the function, and printed after the call.

```sh
# void get_version(int* major, int* minor)
libcall -ltest -L ./test/fixtures/libtest/build get_version out:int out:int -r void

# JSON includes an "outputs" array
libcall --json -ltest -L ./test/fixtures/libtest/build get_version out:int out:int -r void
```

## Warning

FFI calls are inherently unsafe. You must:

- Provide correct function signatures
- Match argument types exactly
- Handle memory correctly
- Understand ABI compatibility

Incorrect usage can crash your program.

## Development

```sh
bundle install
bundle exec rake test
```

## License

MIT
