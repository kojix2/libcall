# Examples (lightweight)

This directory intentionally stays minimal. You can try libcall quickly using system libraries, and optionally build a small test fixture via Rake.

## Quick try

Use libm on Linux or libSystem on macOS:

```bash
# Linux (libm)
libcall -lm sqrt 16.0f64 -r f64

# macOS (libSystem)
libcall /usr/lib/libSystem.B.dylib sqrt 16.0f64 -r f64
```

JSON and dry-run:

```bash
libcall --json -lm sqrt 9.0f64 -r f64
libcall --dry-run -lm pow 2.0f64 10.0f64 -r f64
```

## Optional: build a tiny fixture

If you want a custom library for experiments, Rake can build one for tests:

```bash
# Builds test/fixtures/libtest/build/libtest.{so|dylib}
bundle exec rake build:fixtures

# Then call functions in that library
libcall -ltest -L test/fixtures/libtest/build add_i32 10i32 20i32 -r i32

# Or via pkg-config (with PKG_CONFIG_PATH pointing to the fixture dir)
PKG_CONFIG_PATH=test/fixtures/libtest libcall -llibtest add_i32 10i32 20i32 -r i32
```

Tip: for negative numeric arguments, put `-r/--ret` before `--` since anything after `--` is parsed as positional.
