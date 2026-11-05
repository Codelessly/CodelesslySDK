#include "codelessly_quickjs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "quickjs/quickjs.h"

struct cljs {
  JSRuntime *rt;
  JSContext *ctx;
  // Monotonic time in ms after which running code is interrupted, 0 for
  // none.
  int64_t deadline;
  // Set when the interrupt handler stopped the code. Never cleared: an
  // interrupt can land inside promise bookkeeping and leave the runtime's
  // state inconsistent, so everything the runtime returns afterwards is the
  // time-limit error and the caller throws it away.
  int interrupted;
};

static const char kInterrupted[] =
    "\x01{\"name\":\"InternalError\",\"message\":\"interrupted\",\"limit\":\"time\"}";

static int64_t now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int interrupt_handler(JSRuntime *rt, void *opaque) {
  (void)rt;
  cljs_t *s = (cljs_t *)opaque;
  if (s->deadline != 0 && now_ms() > s->deadline) {
    s->interrupted = 1;
    return 1;
  }
  return 0;
}

FFI_PLUGIN_EXPORT cljs_t *cljs_new(int64_t memory_limit, int64_t stack_size) {
  cljs_t *s = (cljs_t *)calloc(1, sizeof(cljs_t));
  if (!s) return NULL;
  s->rt = JS_NewRuntime();
  if (!s->rt) {
    free(s);
    return NULL;
  }
  if (memory_limit > 0) JS_SetMemoryLimit(s->rt, (size_t)memory_limit);
  if (stack_size > 0) JS_SetMaxStackSize(s->rt, (size_t)stack_size);
  JS_SetInterruptHandler(s->rt, interrupt_handler, s);
  // The standard intrinsics only: no std, os or any other module, so the
  // code has no files, network, timers or processes.
  s->ctx = JS_NewContext(s->rt);
  if (!s->ctx) {
    JS_FreeRuntime(s->rt);
    free(s);
    return NULL;
  }
  return s;
}

FFI_PLUGIN_EXPORT void cljs_free(cljs_t *s) {
  if (!s) return;
  JS_FreeContext(s->ctx);
  JS_FreeRuntime(s->rt);
  free(s);
}

static char *copy_string(const char *str, size_t len) {
  char *out = (char *)malloc(len + 1);
  if (!out) return NULL;
  memcpy(out, str, len);
  out[len] = 0;
  return out;
}

// Appends text to a growing buffer, escaping it as a JSON string body.
static void json_escape(char **buf, size_t *len, size_t *cap, const char *text) {
  for (const unsigned char *p = (const unsigned char *)text; p && *p; p++) {
    if (*len + 8 >= *cap) {
      *cap = *cap * 2 + 64;
      *buf = (char *)realloc(*buf, *cap);
      if (!*buf) return;
    }
    unsigned char c = *p;
    if (c == '"' || c == '\\') {
      (*buf)[(*len)++] = '\\';
      (*buf)[(*len)++] = (char)c;
    } else if (c < 0x20) {
      *len += (size_t)snprintf(*buf + *len, 8, "\\u%04x", c);
    } else {
      (*buf)[(*len)++] = (char)c;
    }
  }
}

static void json_append(char **buf, size_t *len, size_t *cap, const char *raw) {
  size_t n = strlen(raw);
  if (*len + n + 1 >= *cap) {
    *cap = *cap * 2 + n + 64;
    *buf = (char *)realloc(*buf, *cap);
    if (!*buf) return;
  }
  memcpy(*buf + *len, raw, n);
  *len += n;
}

// Reads a string property of the exception value, or NULL.
static const char *exception_string(JSContext *ctx, JSValueConst e, const char *prop) {
  if (!JS_IsObject(e)) return NULL;
  JSValue v = JS_GetPropertyStr(ctx, e, prop);
  const char *str = JS_IsUndefined(v) ? NULL : JS_ToCString(ctx, v);
  JS_FreeValue(ctx, v);
  return str;
}

// The pending exception as a JSON object, with "limit" set to "time",
// "memory" or "depth" when a limit stopped the code. Clears the exception.
static char *exception_json(cljs_t *s) {
  JSContext *ctx = s->ctx;
  JSValue e = JS_GetException(ctx);
  const char *name = exception_string(ctx, e, "name");
  const char *message = exception_string(ctx, e, "message");
  const char *stack = exception_string(ctx, e, "stack");
  const char *text = NULL;
  if (!message) text = JS_ToCString(ctx, e);
  const char *limit = NULL;
  const char *msg = message ? message : text ? text : "";
  if (s->interrupted) {
    limit = "time";
  } else if (strstr(msg, "out of memory") != NULL) {
    limit = "memory";
  } else if (strstr(msg, "stack overflow") != NULL ||
             strstr(msg, "Maximum call stack") != NULL) {
    limit = "depth";
  }
  size_t len = 0, cap = 256;
  char *buf = (char *)malloc(cap);
  if (buf) {
    json_append(&buf, &len, &cap, "{\"name\":\"");
    json_escape(&buf, &len, &cap, name ? name : "Error");
    json_append(&buf, &len, &cap, "\",\"message\":\"");
    json_escape(&buf, &len, &cap, msg);
    json_append(&buf, &len, &cap, "\",\"stack\":\"");
    json_escape(&buf, &len, &cap, stack ? stack : "");
    json_append(&buf, &len, &cap, "\"");
    if (limit) {
      json_append(&buf, &len, &cap, ",\"limit\":\"");
      json_append(&buf, &len, &cap, limit);
      json_append(&buf, &len, &cap, "\"");
    }
    json_append(&buf, &len, &cap, "}");
    if (buf) buf[len] = 0;
  }
  if (name) JS_FreeCString(ctx, name);
  if (message) JS_FreeCString(ctx, message);
  if (stack) JS_FreeCString(ctx, stack);
  if (text) JS_FreeCString(ctx, text);
  JS_FreeValue(ctx, e);
  return buf;
}

// Runs promise reactions until none are left. Returns 0, or -1 with the
// exception pending when a job threw.
static int run_jobs(cljs_t *s) {
  JSContext *job_ctx;
  for (;;) {
    int r = JS_ExecutePendingJob(s->rt, &job_ctx);
    if (r == 0) return 0;
    if (r < 0) return -1;
  }
}

static void start_clock(cljs_t *s, int64_t timeout_ms) {
  s->deadline = timeout_ms > 0 ? now_ms() + timeout_ms : 0;
}

FFI_PLUGIN_EXPORT char *cljs_eval(cljs_t *s, const char *code, int64_t len,
                                  const char *filename, int64_t timeout_ms) {
  if (s->interrupted) return copy_string(kInterrupted + 1, sizeof(kInterrupted) - 2);
  start_clock(s, timeout_ms);
  JSValue v = JS_Eval(s->ctx, code, (size_t)len, filename, JS_EVAL_TYPE_GLOBAL);
  char *error = NULL;
  if (JS_IsException(v)) {
    error = exception_json(s);
  } else if (run_jobs(s) < 0) {
    error = exception_json(s);
  }
  JS_FreeValue(s->ctx, v);
  s->deadline = 0;
  if (s->interrupted && !error) error = copy_string(kInterrupted + 1, sizeof(kInterrupted) - 2);
  return error;
}

FFI_PLUGIN_EXPORT char *cljs_call(cljs_t *s, const char *name, const char *arg,
                                  int64_t arg_len, int64_t timeout_ms) {
  JSContext *ctx = s->ctx;
  if (s->interrupted) return copy_string(kInterrupted, sizeof(kInterrupted) - 1);
  start_clock(s, timeout_ms);
  JSValue global = JS_GetGlobalObject(ctx);
  JSValue fn = JS_GetPropertyStr(ctx, global, name);
  char *out = NULL;
  if (!JS_IsFunction(ctx, fn)) {
    const char *missing = "\x01{\"name\":\"Error\",\"message\":\"Missing host function\"}";
    out = copy_string(missing, strlen(missing));
  } else {
    JSValue a = JS_NewStringLen(ctx, arg, (size_t)arg_len);
    JSValue ret = JS_Call(ctx, fn, global, 1, &a);
    JS_FreeValue(ctx, a);
    if (JS_IsException(ret) || run_jobs(s) < 0) {
      char *error = exception_json(s);
      size_t n = error ? strlen(error) : 0;
      out = (char *)malloc(n + 2);
      if (out) {
        out[0] = 1;
        if (error) memcpy(out + 1, error, n);
        out[n + 1] = 0;
      }
      free(error);
    } else {
      size_t n;
      const char *str = JS_ToCStringLen(ctx, &n, ret);
      if (str) {
        out = copy_string(str, n);
        JS_FreeCString(ctx, str);
      } else {
        const char *oom = "\x01{\"name\":\"InternalError\",\"message\":\"out of memory\",\"limit\":\"memory\"}";
        JS_FreeValue(ctx, JS_GetException(ctx));
        out = copy_string(oom, strlen(oom));
      }
    }
    JS_FreeValue(ctx, ret);
  }
  JS_FreeValue(ctx, fn);
  JS_FreeValue(ctx, global);
  s->deadline = 0;
  if (s->interrupted) {
    free(out);
    return copy_string(kInterrupted, sizeof(kInterrupted) - 1);
  }
  return out;
}

FFI_PLUGIN_EXPORT int64_t cljs_memory_used(cljs_t *s) {
  JSMemoryUsage usage;
  JS_ComputeMemoryUsage(s->rt, &usage);
  return usage.memory_used_size;
}

FFI_PLUGIN_EXPORT uint8_t *cljs_alloc(int64_t n) {
  return (uint8_t *)malloc((size_t)(n > 0 ? n : 1));
}

FFI_PLUGIN_EXPORT void cljs_dealloc(void *p) { free(p); }

FFI_PLUGIN_EXPORT void cljs_free_string(char *p) { free(p); }

FFI_PLUGIN_EXPORT const char *cljs_version(void) { return CONFIG_VERSION; }
