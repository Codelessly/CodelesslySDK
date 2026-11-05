// A small C API over QuickJS for running Codelessly scripts from Dart FFI.
//
// Each cljs_t is one isolated JavaScript runtime with its own heap. It has
// no std/os modules: no files, network, timers or processes. Its memory,
// stack and running time are limited. Strings cross the boundary as UTF-8
// and every string this API returns must be freed with cljs_free_string.
#ifndef CODELESSLY_QUICKJS_H
#define CODELESSLY_QUICKJS_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

typedef struct cljs cljs_t;

// Creates a runtime whose heap is limited to memory_limit bytes and whose
// stack to stack_size bytes (0 keeps QuickJS's defaults). Returns NULL when
// it can't be created.
FFI_PLUGIN_EXPORT cljs_t *cljs_new(int64_t memory_limit, int64_t stack_size);

// Frees the runtime and everything in it.
FFI_PLUGIN_EXPORT void cljs_free(cljs_t *s);

// Evaluates a UTF-8 script of len bytes as global code named filename,
// then runs pending jobs. Returns NULL on success, or a JSON error object
// {"name", "message", "stack", "limit"?}. Stops after timeout_ms
// milliseconds (0 for no limit) with "limit": "time".
FFI_PLUGIN_EXPORT char *cljs_eval(cljs_t *s, const char *code, int64_t len,
                                  const char *filename, int64_t timeout_ms);

// Calls the global function `name` with one string argument, then runs the
// pending jobs (promise reactions) until there are none. Returns the
// function's result converted to a string, or a JSON error object prefixed
// with the byte 0x01. Stops after timeout_ms milliseconds (0 for no limit).
FFI_PLUGIN_EXPORT char *cljs_call(cljs_t *s, const char *name, const char *arg,
                                  int64_t arg_len, int64_t timeout_ms);

// Bytes of memory the runtime's heap uses now.
FFI_PLUGIN_EXPORT int64_t cljs_memory_used(cljs_t *s);

// Allocates n bytes for the caller to pass strings in, or NULL.
FFI_PLUGIN_EXPORT uint8_t *cljs_alloc(int64_t n);

// Frees memory from cljs_alloc.
FFI_PLUGIN_EXPORT void cljs_dealloc(void *p);

// Frees a string this API returned.
FFI_PLUGIN_EXPORT void cljs_free_string(char *p);

// The QuickJS version, e.g. "2025-04-26". Not to be freed.
FFI_PLUGIN_EXPORT const char *cljs_version(void);

#endif
