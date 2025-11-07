// Simple test library for libcall (test fixture)
// Compiles to shared library in build/ by Rake tasks.

#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

// Integer addition
int32_t add_i32(int32_t a, int32_t b)
{
    return a + b;
}

// Unsigned integer addition
uint64_t add_u64(uint64_t a, uint64_t b)
{
    return a + b;
}

// Float multiplication
float mul_f32(float a, float b)
{
    return a * b;
}

// Double multiplication
double mul_f64(double a, double b)
{
    return a * b;
}

// String length
int32_t str_length(const char *s)
{
    if (s == NULL)
        return 0;
    return strlen(s);
}

// Echo string (WARNING: caller must free!)
char *echo_string(const char *s)
{
    if (s == NULL)
        return NULL;
    char *result = strdup(s);
    return result;
}

// Void function (side effect only)
void print_hello(void)
{
    // no-op for testing
}

// Output parameters example: writes version numbers
void get_version(int32_t *major, int32_t *minor)
{
    if (major)
        *major = 1;
    if (minor)
        *minor = 2;
}

// Output string via char** (caller must free())
void out_echo_string(const char *s, char **out)
{
    if (!out)
        return;
    if (s == NULL)
    {
        *out = NULL;
    }
    else
    {
        *out = strdup(s);
    }
}

// Sum of int32 array
int32_t sum_i32_array(const int32_t *arr, size_t n)
{
    if (!arr)
        return 0;
    int64_t sum = 0;
    for (size_t i = 0; i < n; i++)
    {
        sum += arr[i];
    }
    return (int32_t)sum;
}

// Fill sequence 0..n-1 into out array
void fill_seq_i32(int32_t *out_arr, size_t n)
{
    if (!out_arr)
        return;
    for (size_t i = 0; i < n; i++)
    {
        out_arr[i] = (int32_t)i;
    }
}

// Apply a callback to two integers: int op(int a, int b)
int32_t apply_i32(int32_t a, int32_t b, int32_t (*op)(int32_t, int32_t))
{
    if (!op)
        return 0;
    return op(a, b);
}

// Sort copy of input array into out using qsort and provided comparator
void sort_i32_copy(const int32_t *in, int32_t *out, size_t n, int (*compar)(const void *, const void *))
{
    if (!in || !out || n == 0)
        return;
    for (size_t i = 0; i < n; ++i)
        out[i] = in[i];
    if (compar) {
        qsort(out, n, sizeof(int32_t), compar);
    } else {
        // default ascending compare
        int cmp_default(const void *a, const void *b)
        {
            int32_t av = *(const int32_t *)a;
            int32_t bv = *(const int32_t *)b;
            if (av < bv) return -1;
            if (av > bv) return 1;
            return 0;
        }
        qsort(out, n, sizeof(int32_t), cmp_default);
    }
}
