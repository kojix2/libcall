# libcall

Call C functions in shared libraries from the command line.

## Installation

```sh
gem install libcall
```

## Usage

```sh
libcall [OPTIONS] <LIBRARY> <FUNCTION> [ARGS...]
```

### Quick Examples

```sh
# Math function with type suffix
libcall -lm sqrt 16.0f64 -r f64
# => 4.0

# Custom library
libcall ./mylib.so add 10i32 20i32 -r i32
# => 30
```

### Type Syntax

Use Rust-style type suffixes:

- Integers: `42i32`, `100u64`, `255u8`
- Floats: `3.14f64`, `2.5f32`
- Strings: `"hello"`

### Options

- `-l LIBRARY` - library name (searches standard paths)
- `-L PATH` - add library search path
- `-r TYPE` - return type (void, i32, f64, cstr, ptr)
- `--dry-run` - validate without executing
- `--json` - JSON output
- `--verbose` - detailed info
- `-h, --help` - show help
- `-v, --version` - show version

### More Examples

```sh
# JSON output
libcall --json -lm sqrt 9.0f64 -r f64

# Dry run
libcall --dry-run ./mylib.so test 42i32 -r void

# Using -L and -l (like gcc)
libcall -lmylib -L./build add 10i32 20i32 -r i32
```

## Type Reference

| Suffix | Type | Range/Note |
|--------|------|------------|
| `i8` | signed 8-bit | -128 to 127 |
| `u8` | unsigned 8-bit | 0 to 255 |
| `i16` | signed 16-bit | -32768 to 32767 |
| `u16` | unsigned 16-bit | 0 to 65535 |
| `i32` | signed 32-bit | standard int |
| `u32` | unsigned 32-bit | unsigned int |
| `i64` | signed 64-bit | long long |
| `u64` | unsigned 64-bit | unsigned long long |
| `f32` | 32-bit float | single precision |
| `f64` | 64-bit float | double precision |

## pkg-config Support

Set `PKG_CONFIG_PATH` and use package names with `-l`:

```sh
PKG_CONFIG_PATH=/path/to/pkgconfig libcall -lmypackage func 42i32 -r i32
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
