// Simple test library for libcall (test fixture)
// Compiles to shared library in build/ by Rake tasks.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Integer addition
int32_t add_i32(int32_t a, int32_t b) {
    return a + b;
}

// Unsigned integer addition
uint64_t add_u64(uint64_t a, uint64_t b) {
    return a + b;
}

// Float multiplication
float mul_f32(float a, float b) {
    return a * b;
}

// Double multiplication
double mul_f64(double a, double b) {
    return a * b;
}

// String length
int32_t str_length(const char* s) {
    if (s == NULL) return 0;
    return strlen(s);
}

// Echo string (WARNING: caller must free!)
char* echo_string(const char* s) {
    if (s == NULL) return NULL;
    char* result = strdup(s);
    return result;
}

// Void function (side effect only)
void print_hello(void) {
    // no-op for testing
}
