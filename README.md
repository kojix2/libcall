# libcall

[![test](https://github.com/kojix2/libcall/actions/workflows/main.yml/badge.svg)](https://github.com/kojix2/libcall/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/libcall.svg)](https://badge.fury.io/rb/libcall)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Flibcall%2Flines)](https://tokei.kojix2.net/github/kojix2/libcall)

Call C functions in shared libraries from the command line.

## Installation

```sh
gem install libcall
```

### Quick Examples

```sh
libcall -lm sqrt double 16 -r double # => 4.0
```

```sh
libcall -lc strlen string "hello" -r usize # => 5
```

## Usage

```sh
libcall [OPTIONS] <LIBRARY> <FUNCTION> (TYPE VALUE)...
```

### Options

- `-l LIBRARY` - library name (searches standard paths)
- `-L PATH` - add library search path
- `-r TYPE` - return type (void, i32, f64, cstr, ptr)
- `--dry-run` - validate without executing
- `--json` - JSON output
- `--verbose` - detailed info
- `-h, --help` - show help
- `-v, --version` - show version

Library search:

- `-L` adds search paths; `-l` resolves by name
- On Linux and macOS, `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH` are honored

### More Examples

Output parameter with libm

```sh
libcall -lm modf double -3.14 out:double -r f64
# Result: -0.14000000000000012
# Output parameters:
#   [1] double = -3.0
```

JSON output

```sh
libcall --json -lm sqrt double 9.0 -r f64
# {
#   "library": "/lib/x86_64-linux-gnu/libm.so",
#   "function": "sqrt",
#   "return_type": "double",
#   "result": 3.0
# }
```

Dry run

```sh
libcall --dry-run -lc getpid -r int
# Library:  /lib/x86_64-linux-gnu/libc.so
# Function: getpid
# Return:   int
```

## Type Reference

libcall supports multiple naming conventions for types, making it easy to work with C libraries.

### Integer Types

| Short (Rust-like) | C Standard                 | C99/stdint.h           | Size               |
| ----------------- | -------------------------- | ---------------------- | ------------------ |
| `i8` / `u8`       | `char` / `uchar`           | `int8_t` / `uint8_t`   | 1 byte             |
| `i16` / `u16`     | `short` / `ushort`         | `int16_t` / `uint16_t` | 2 bytes            |
| `i32` / `u32`     | `int` / `uint`             | `int32_t` / `uint32_t` | 4 bytes            |
| `i64` / `u64`     | `long_long` / `ulong_long` | `int64_t` / `uint64_t` | 8 bytes            |
| `isize` / `usize` | `long` / `ulong`           | `ssize_t` / `size_t`   | platform-dependent |

**Alternative names**: You can use any of these:

- C-style: `char`, `short`, `int`, `long`, `unsigned_int`, etc.
- stdint-style: `int8`, `int16`, `int32`, `int64`, `uint8`, `uint16`, etc.
- With `_t` suffix: `int8_t`, `uint8_t`, `int32_t`, `size_t`, etc.

### Floating Point Types

| Short | C Standard | Alternative | Size    | Precision  |
| ----- | ---------- | ----------- | ------- | ---------- |
| `f32` | `float`    | `float32`   | 4 bytes | ~7 digits  |
| `f64` | `double`   | `float64`   | 8 bytes | ~15 digits |

### Pointer Types

| Type      | Description                | Usage                            |
| --------- | -------------------------- | -------------------------------- |
| `ptr`     | Generic pointer (void\*)   | For arbitrary memory addresses   |
| `pointer` | Alias for `ptr`            | Same as `ptr`                    |
| `voidp`   | Void pointer               | Same as `ptr`                    |
| `string`  | C string argument (char\*) | For passing strings to functions |
| `cstr`    | C string return (char\*)   | For return values only           |
| `str`     | Alias for `string`         | Same as `string`                 |

**Null pointer values**: Use `null`, `NULL`, `nil`, or `0` to pass a null pointer.

### Special Types

| Type                     | Description                 | Alternative names    |
| ------------------------ | --------------------------- | -------------------- |
| `void`                   | No value (return type only) | —                    |
| `size_t`                 | Platform size type          | `usize` (unsigned)   |
| `ssize_t`                | Signed size type            | `isize` (signed)     |
| `intptr_t` / `uintptr_t` | Pointer-sized integer       | `intptr` / `uintptr` |
| `ptrdiff_t`              | Pointer difference type     | —                    |
| `bool`                   | Boolean (as int)            | —                    |

### Output Parameters

Prefix any type with `out:` to create an output parameter:

```sh
out:int       # Output integer pointer (int*)
out:double    # Output double pointer (double*)
out:string    # Output string pointer (char**)
```

### Array Types

| Syntax        | Description                   | Example              |
| ------------- | ----------------------------- | -------------------- |
| `TYPE[]`      | Input array                   | `int[] 1,2,3,4,5`    |
| `out:TYPE[N]` | Output array of N elements    | `out:int[10]`        |
| `out:TYPE[N]` | Output array with initializer | `out:int[4] 4,3,2,1` |

### Callback Types

| Keyword    | Description                 | Example                          |
| ---------- | --------------------------- | -------------------------------- |
| `func`     | Function pointer (callback) | `func 'int(int a,int b){ a+b }'` |
| `callback` | Alias for `func`            | Same as above                    |

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

## pkg-config Support

Set `PKG_CONFIG_PATH` and use package names with `-l`:

```sh
PKG_CONFIG_PATH=/path/to/pkgconfig libcall -lmypackage func i32 42 -r i32
```

## Output parameters (out:TYPE)

You can pass output pointers by specifying `out:TYPE`. The pointer is allocated automatically, passed to the function, and printed after the call.

```sh
# double frexp(double x, int* exp)
libcall -lm frexp double 8.0 out:int -r f64

# JSON includes an "outputs" array
libcall --json -lm frexp double 8.0 out:int -r f64
```

## Arrays

- Input arrays: `TYPE[]` takes a comma-separated value list.

```sh
# zlib (Linux/macOS): uLong crc32(uLong crc, const Bytef* buf, uInt len)
libcall -lz crc32 uint 0 uchar[] 104,101,108,108,111 uint 5 -r uint
```

- Output arrays: `out:TYPE[N]` allocates N elements and prints them after the call.

```sh
# Linux (libc): ssize_t getrandom(void* buf, size_t buflen, unsigned int flags)
libcall -lc getrandom out:uchar[16] size_t 16 uint 0 -r long
```

```sh
# macOS (libSystem): void arc4random_buf(void* buf, size_t nbytes)
libcall -lSystem arc4random_buf out:uchar[16] size_t 16 -r void
```

## Callbacks (experimental)

Pass a C function pointer via a Ruby callback. Use `func` or `callback` with a quoted spec:

- Syntax: `func 'RET(ARG,ARG,...){|a, b, ...| ruby_code }'` (alias: `callback ...`)
- Inside the block, helper methods from `Libcall::Fiddley::DSL` are available:
  - `int(ptr)`, `double(ptr)`, `cstr(ptr)` read values from pointers
  - `read(:type, ptr)` reads any supported type; `ptr(addr)` makes a pointer

Quick examples

```sh
# Fixture function: int32_t apply_i32(int32_t, int32_t, int32_t (*)(int32_t,int32_t))
libcall -ltest -L test/fixtures/libtest/build apply_i32 \
	int 3 int 5 \
	func 'int(int,int){|a,b| a + b}' \
	-r i32
# => 8
```

```sh
# libc qsort: sort 4 ints ascending; use out:int[4] with an initializer so the result prints
libcall -lc qsort \
	out:int[4] 4,2,3,1 \
	size_t 4 \
	size_t 4 \
	callback 'int(void* a, void* b){ int(a) <=> int(b) }' \
	-r void
# Output parameters:
#   [0] int[4] = [1, 2, 3, 4]
```

Notes

- Match the C signature exactly (types and arity). Blocks run in-process; exceptions abort the call.

## Warning

FFI calls are inherently unsafe. You must:

- Provide correct function signatures
- Match argument types exactly
- Handle memory correctly
- Understand ABI compatibility

Incorrect usage can crash your program.

## Windows Support

Supports DLLs (e.g., `msvcrt.dll`, `kernel32.dll`). Searches in System32, PATH, and MSYS2/MinGW directories. For building custom DLLs, RubyInstaller with DevKit is recommended.

### Windows Examples

```powershell
# Calling C runtime functions
libcall msvcrt.dll sqrt double 16.0 -r f64 # => 4.0
```

```powershell
# Accessing environment variables
libcall msvcrt.dll getenv string "PATH" -r cstr
```

## Development

```sh
bundle install
bundle exec rake test
```

## License

MIT
