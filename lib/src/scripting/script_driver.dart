/// The JavaScript that runs inside every script engine before any script.
///
/// The same driver runs in QuickJS on Android, iOS and desktop, and in a
/// Web Worker (V8, SpiderMonkey or JavaScriptCore) on the web, so scripts
/// see the same globals and behave the same everywhere.
library;

/// The driver's source. See [scriptDriver] for what it does.
///
/// It defines three global functions the host calls with a JSON string and
/// that return a JSON string:
///
/// * `__cl_start(request)` starts a run: `{run, source, paramNames,
///   params, vars, nodes, grants, seed, now, scripts}`.
/// * `__cl_resume(responses)` delivers the results of host calls:
///   `{run, responses: [{id, ok, value | error}]}`.
/// * `__cl_check(request)` compiles `{source, paramNames}` without
///   running it: '' when it compiles, else the error as JSON.
/// * `__cl_state(run)` reports what a run did since the last report, once
///   its pending jobs have run: `{run, status: 'waiting' | 'done' |
///   'error', events: [{type: 'write', name, value} | {type: 'call', id,
///   name, args}], logs, value, error}`.
///
/// Before anything else it locks the global scope down: every global that
/// isn't standard ECMAScript is removed (fetch, XMLHttpRequest, WebSocket,
/// importScripts, timers, storage, WebAssembly, Intl, workers, ...),
/// including from the global object's prototypes, and every remaining
/// intrinsic is frozen, so a script can't reach the network, files or
/// timers, and can't change what the next run sees.
///
/// For determinism it replaces `Math.random` with a seeded generator per
/// run, makes `Date` UTC-only and reading the clock a capability, computes
/// `Math.pow` with a whole exponent by repeated squaring, and gives
/// `toLocaleString` and `localeCompare` fixed en-US behavior on every
/// engine.
const String scriptDriver = r'''
(function (global) {
  'use strict';

  // --- What the driver keeps for itself before the lockdown -------------
  const indirectEval = global.eval;
  const RealDate = global.Date;
  const realPow = Math.pow;
  const ObjectKeys = Object.keys;
  const JSONstringify = JSON.stringify;
  const JSONparse = JSON.parse;
  const defineProperty = Object.defineProperty;
  const getOwnPropertyNames = Object.getOwnPropertyNames;
  const getPrototypeOf = Object.getPrototypeOf;
  const freeze = Object.freeze;
  const isFrozen = Object.isFrozen;

  // --- Lockdown -------------------------------------------------------
  const allowed = new Set([
    'Object', 'Function', 'Array', 'Number', 'parseFloat', 'parseInt',
    'Infinity', 'NaN', 'undefined', 'Boolean', 'String', 'Symbol', 'Date',
    'Promise', 'RegExp', 'Error', 'AggregateError', 'EvalError',
    'RangeError', 'ReferenceError', 'SyntaxError', 'TypeError', 'URIError',
    'globalThis', 'JSON', 'Math', 'ArrayBuffer', 'Uint8Array', 'Int8Array',
    'Uint16Array', 'Int16Array', 'Uint32Array', 'Int32Array',
    'Float32Array', 'Float64Array', 'Uint8ClampedArray', 'BigUint64Array',
    'BigInt64Array', 'DataView', 'Map', 'BigInt', 'Set', 'WeakMap',
    'WeakSet', 'Proxy', 'Reflect', 'decodeURI', 'decodeURIComponent',
    'encodeURI', 'encodeURIComponent', 'escape', 'unescape', 'isFinite',
    'isNaN', 'Iterator',
    '__cl_start', '__cl_resume', '__cl_state', '__cl_check', 'structuredClone',
  ]);
  const removed = new Set();
  for (let o = global; o && o !== Object.prototype; o = getPrototypeOf(o)) {
    for (const name of getOwnPropertyNames(o)) {
      if (allowed.has(name) || name === 'constructor' && o !== global) continue;
      removed.add(name);
      try { delete o[name]; } catch (_) {}
    }
  }
  // Names that couldn't be deleted are shadowed on the global object.
  for (const name of removed) {
    if (name in global) {
      try {
        defineProperty(global, name, { value: undefined, writable: false, configurable: false });
      } catch (_) {}
    }
  }

  // No code generated at run time: `eval` is gone, and Function and its
  // async and generator kin (reachable as `fn.constructor`) throw. With no
  // way to make code, a script can't hide an `import()` from the check in
  // compile() (in a browser worker, import() fetches code).
  const noCodegen = function () {
    throw new EvalError('Scripts can\'t generate code at run time (eval, new Function).');
  };
  const AsyncFunction = (async function () {}).constructor;
  const GeneratorFunction = (function* () {}).constructor;
  const AsyncGeneratorFunction = (async function* () {}).constructor;
  for (const F of [Function, AsyncFunction, GeneratorFunction, AsyncGeneratorFunction]) {
    const stub = function () { return noCodegen(); };
    defineProperty(stub, 'prototype', { value: F.prototype });
    defineProperty(F.prototype, 'constructor', { value: stub, writable: false, configurable: false });
    if (F === Function) global.Function = stub;
  }

  // --- Runs -----------------------------------------------------------
  const runs = new Map();
  let current = null;

  function namedError(name, message) {
    const e = new Error(message);
    defineProperty(e, 'name', { value: name, writable: true, configurable: true });
    return e;
  }

  function capabilityError(what, grant) {
    return namedError('CapabilityError', what + ' needs the "' + grant + '" capability. Grant it to the script in its settings.');
  }

  function need(run, grant, what) {
    if (!run.grants.has(grant)) throw capabilityError(what, grant);
  }

  // A JSON-safe copy, so the host gets plain data and the script can't
  // keep references into what it handed over.
  function plain(value, what) {
    if (value === undefined) return null;
    let text;
    try {
      text = JSONstringify(value);
    } catch (e) {
      const err = new TypeError(what + ' must be JSON data: ' + e.message);
      throw err;
    }
    return text === undefined ? null : JSONparse(text);
  }

  // Seeded PRNG (mulberry32).
  function nextRandom(run) {
    let t = (run.rand = (run.rand + 0x6D2B79F5) | 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  function clockNow() {
    const run = current;
    if (!run || !run.grants.has('clock')) {
      throw capabilityError('Reading the current time', 'clock');
    }
    return run.now + (run.started ? RealDate.now() - run.started : 0);
  }

  function inspect(v) {
    if (typeof v === 'string') return v;
    if (v === undefined) return 'undefined';
    if (typeof v === 'function') return '[Function ' + (v.name || 'anonymous') + ']';
    if (v instanceof Error) return v.name + ': ' + v.message;
    if (v instanceof Map) return 'Map(' + v.size + ') ' + inspect([...v]);
    if (v instanceof Set) return 'Set(' + v.size + ') ' + inspect([...v]);
    try {
      const s = JSONstringify(v);
      return s === undefined ? String(v) : s;
    } catch (_) {
      return String(v);
    }
  }

  function makeConsole(run) {
    const log = (level) => (...args) => {
      if (run.logs.length + run.logCount >= 500) return;
      let message = args.map(inspect).join(' ');
      if (message.length > 2000) message = message.slice(0, 2000) + '…';
      run.logs.push({ level, message });
    };
    return freeze({ log: log('log'), info: log('info'), warn: log('warn'), error: log('error'), debug: log('debug') });
  }

  function hostCall(run, name, args, grant, what) {
    need(run, grant, what);
    const id = run.nextCall++;
    run.events.push({ type: 'call', id, name, args: plain(args, 'The arguments of app.' + name) });
    return new Promise((resolve, reject) => run.pending.set(id, { resolve, reject }));
  }

  function makeVars(run) {
    return freeze({
      get(name) {
        need(run, 'variables.read', 'vars.get()');
        if (!Object.prototype.hasOwnProperty.call(run.vars, name)) {
          throw new ReferenceError('There is no variable named "' + name + '".');
        }
        return plain(run.vars[name], 'A variable');
      },
      has(name) {
        need(run, 'variables.read', 'vars.has()');
        return Object.prototype.hasOwnProperty.call(run.vars, name);
      },
      all() {
        need(run, 'variables.read', 'vars.all()');
        return plain(run.vars, 'The variables');
      },
      set(name, value) {
        need(run, 'variables.write', 'vars.set()');
        if (!Object.prototype.hasOwnProperty.call(run.vars, name)) {
          throw new ReferenceError('There is no variable named "' + name + '".');
        }
        const v = plain(value, 'The value of vars.set("' + name + '")');
        run.vars[name] = v;
        run.events.push({ type: 'write', name, value: v });
        return v;
      },
    });
  }

  function makeNodes(run) {
    return freeze({
      value(id) {
        need(run, 'nodes.read', 'nodes.value()');
        const v = run.nodes[id];
        return v === undefined ? null : plain(v, 'A node value');
      },
      all() {
        need(run, 'nodes.read', 'nodes.all()');
        return plain(run.nodes, 'The node values');
      },
    });
  }

  function makeApp(run) {
    return freeze({
      navigate: (target, params) => hostCall(run, 'navigate', [target, params ?? null], 'navigation', 'app.navigate()'),
      back: (result) => hostCall(run, 'back', [result ?? null], 'navigation', 'app.back()'),
      callApi: (name, inputs) => hostCall(run, 'callApi', [name, inputs ?? null], 'api', 'app.callApi()'),
      cloudData: (request) => hostCall(run, 'cloudData', [request], 'cloud', 'app.cloudData()'),
      runAction: (action) => hostCall(run, 'runAction', [action], 'actions', 'app.runAction()'),
      toast: (message) => hostCall(run, 'toast', [String(message)], 'actions', 'app.toast()'),
      delay: (ms) => hostCall(run, 'delay', [Number(ms) || 0], 'actions', 'app.delay()'),
      yield: (ms) => hostCall(run, 'yield', [Number(ms) || 0], 'actions', 'app.yield()'),
    });
  }

  const reserved = new Set(['vars', 'nodes', 'app', 'console', 'fmt', 'script', 'params']);

  // The source without comments and the contents of strings, for checks.
  function codeOnly(source) {
    return source
      .replace(/\/\*[\s\S]*?\*\//g, ' ')
      .replace(/\/\/[^\n]*/g, ' ')
      .replace(/'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"/g, '""');
  }

  function compile(source, paramNames) {
    if (/\bimport\s*(\(|\.\s*meta\b)/.test(codeOnly(String(source)))) {
      throw new SyntaxError('Scripts can\'t import code. Call other scripts with script.name(...).');
    }
    for (const p of paramNames) {
      if (!/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(p) || reserved.has(p)) {
        throw new SyntaxError('"' + p + '" can\'t be a parameter name.');
      }
    }
    // Everything before the source is on its first line, so its line
    // numbers are the script's own. The source is in a block of its own,
    // so its declarations shadow the host names (a script may declare its
    // own `nodes` or `app`) instead of clashing with them.
    const head = '(async function __script(vars, nodes, app, console, fmt, script, params' +
      (paramNames.length ? ', ' + paramNames.join(', ') : '') + ') {"use strict"; {';
    const tail = '\n;return typeof main === "function" ? main(' + paramNames.join(', ') + ') : undefined;\n}})';
    return { fn: indirectEval(head + source + tail + '\n//# sourceURL=script.js'), headLength: head.length };
  }

  function makeScripts(run) {
    const cache = new Map();
    return new Proxy(Object.create(null), {
      get(_, name) {
        if (typeof name !== 'string') return undefined;
        const def = run.scripts[name];
        if (!def) return undefined;
        return (...args) => {
          if (run.depth > 32) throw new RangeError('Scripts called each other more than 32 deep.');
          let compiled = cache.get(name);
          if (!compiled) {
            compiled = compile(def.source, def.paramNames || []);
            cache.set(name, compiled);
          }
          const values = (def.paramNames || []).map((_, i) => plain(args[i], 'An argument of script.' + name));
          const params = {};
          (def.paramNames || []).forEach((p, i) => { params[p] = values[i]; });
          run.depth++;
          return compiled.fn(run.api.vars, run.api.nodes, run.api.app, run.api.console, fmt, run.api.script, freeze(params), ...values)
            .finally(() => { run.depth--; });
        };
      },
      has(_, name) { return typeof name === 'string' && !!run.scripts[name]; },
      set() { throw new TypeError('script is read-only'); },
    });
  }

  // Where a stack frame points into the script: "script.js:3:5" on V8,
  // "<input>:3:5" on QuickJS.
  const framePattern = /(?:script\.js|<input>|<eval>|eval at[^)]*\)):(\d+)(?::(\d+))?/;

  function errorData(e, run) {
    if (e instanceof Error || (e && typeof e === 'object' && 'message' in e)) {
      const stack = String(e.stack || '');
      const out = { type: String(e.name || 'Error'), message: String(e.message) };
      const m = framePattern.exec(stack);
      if (m) {
        out.line = Number(m[1]);
        if (m[2] !== undefined) {
          let column = Number(m[2]);
          if (out.line === 1 && run && run.headLength) column -= run.headLength;
          if (column >= 1) out.column = column;
        }
      }
      // The script functions the error passed through, innermost first,
      // with repeats collapsed: ["fib ×512", "main"].
      const names = [];
      for (const line of stack.split('\n')) {
        const f = /at (?:async )?([A-Za-z_$][\w$.]*) \(/.exec(line);
        if (!f || f[1] === '__script' || /^(eval|Object|Array|Promise|new)$/.test(f[1]) || !framePattern.test(line)) continue;
        const last = names[names.length - 1];
        if (last && last.name === f[1]) last.count++;
        else names.push({ name: f[1], count: 1 });
      }
      if (names.length) out.stack = names.slice(0, 20).map((n) => n.count > 1 ? n.name + ' ×' + n.count : n.name);
      return out;
    }
    return { type: 'Error', message: inspect(e), thrown: plain(e, 'The thrown value') };
  }

  function finish(run, status, data) {
    if (run.status !== 'running') return;
    run.status = status;
    if (status === 'done') {
      try {
        run.value = plain(data, 'The script\'s result');
      } catch (e) {
        run.status = 'error';
        run.error = errorData(e, run);
      }
    } else {
      run.error = data;
    }
    // Calls still pending when the script ends never resolve.
    run.pending.clear();
  }

  function start(text) {
    const req = JSONparse(text);
    const run = {
      id: req.run,
      grants: new Set(req.grants || []),
      vars: req.vars || {},
      nodes: req.nodes || {},
      scripts: req.scripts || {},
      now: req.now || 0,
      started: req.now ? RealDate.now() : 0,
      rand: (req.seed | 0) || 1,
      events: [], logs: [], logCount: 0,
      pending: new Map(), nextCall: 1, depth: 0,
      status: 'running', value: null, error: null, headLength: 0,
    };
    runs.set(run.id, run);
    current = run;
    run.api = {
      vars: makeVars(run), nodes: makeNodes(run), app: makeApp(run),
      console: makeConsole(run),
    };
    run.api.script = makeScripts(run);
    const paramNames = req.paramNames || [];
    const values = paramNames.map((p) => (req.params || {})[p] ?? null);
    const params = {};
    paramNames.forEach((p, i) => { params[p] = values[i]; });
    let compiled;
    try {
      compiled = compile(req.source, paramNames);
      run.headLength = compiled.headLength;
    } catch (e) {
      finish(run, 'error', errorData(e, run));
      return '';
    }
    let promise;
    try {
      promise = compiled.fn(run.api.vars, run.api.nodes, run.api.app, run.api.console, fmt, run.api.script, freeze(params), ...values);
    } catch (e) {
      finish(run, 'error', errorData(e, run));
      return '';
    }
    promise.then((v) => finish(run, 'done', v), (e) => finish(run, 'error', errorData(e, run)));
    return '';
  }

  function resume(text) {
    const req = JSONparse(text);
    const run = runs.get(req.run);
    if (!run || run.status !== 'running') return '';
    current = run;
    // The variables as they are now (other actions may have changed them
    // while this run waited on the app).
    if (req.vars && typeof req.vars === 'object') run.vars = req.vars;
    for (const r of req.responses || []) {
      const p = run.pending.get(r.id);
      if (!p) continue;
      run.pending.delete(r.id);
      if (r.ok) {
        p.resolve(r.value);
      } else {
        p.reject(namedError(r.error && r.error.type || 'HostError', r.error && r.error.message || 'The host call failed'));
      }
    }
    return '';
  }

  function state(id) {
    const run = runs.get(id);
    if (!run) return JSONstringify({ run: id, status: 'error', error: { type: 'Error', message: 'Unknown run' } });
    const out = { run: id, status: run.status === 'running' ? 'waiting' : run.status, events: run.events, logs: run.logs };
    run.logCount += run.logs.length;
    run.events = [];
    run.logs = [];
    if (run.status === 'done') out.value = run.value;
    if (run.status === 'error') out.error = run.error;
    if (run.status !== 'running') runs.delete(id);
    return JSONstringify(out);
  }

  // --- Deterministic built-ins ---------------------------------------
  defineProperty(Math, 'random', { value: function random() {
    if (!current) return 0.5;
    return nextRandom(current);
  }, writable: false, configurable: false });
  defineProperty(Math, 'pow', { value: function pow(x, y) {
    x = Number(x); y = Number(y);
    // A whole exponent is computed by repeated squaring, which gives the
    // same bits on every engine (engines' pow can differ in the last digit).
    if (Number.isInteger(y) && Math.abs(y) <= 1024 && Number.isFinite(x)) {
      let base = x, e = Math.abs(y), result = 1;
      while (e > 0) {
        if (e & 1) result *= base;
        base *= base;
        e = Math.floor(e / 2);
      }
      return y < 0 ? 1 / result : result;
    }
    return realPow(x, y);
  }, writable: false, configurable: false });

  // Dates: UTC everywhere, and the clock only with the "clock" grant.
  const hasZone = /(Z|[+-]\d\d:?\d\d)$/i;
  function utcText(s) {
    s = String(s).trim();
    // "2026-01-05" and "2026-01-05T10:00" are read as UTC on every device.
    return /^\d{4}-\d\d-\d\d(T\d\d:\d\d(:\d\d(\.\d+)?)?)?$/.test(s) && !hasZone.test(s)
      ? (s.length === 10 ? s + 'T00:00:00Z' : s + 'Z') : s;
  }
  function ClDate(...args) {
    if (!new.target) return new RealDate(clockNow()).toISOString();
    if (args.length === 0) return Reflect.construct(RealDate, [clockNow()], new.target);
    if (args.length === 1) {
      const a = args[0];
      return Reflect.construct(RealDate, [typeof a === 'string' ? utcText(a) : a], new.target);
    }
    return Reflect.construct(RealDate, [RealDate.UTC(...args)], new.target);
  }
  const dateProto = RealDate.prototype;
  ClDate.prototype = dateProto;
  defineProperty(dateProto, 'constructor', { value: ClDate });
  ClDate.now = clockNow;
  ClDate.UTC = RealDate.UTC;
  ClDate.parse = (s) => RealDate.parse(utcText(s));
  for (const k of ['FullYear', 'Month', 'Date', 'Day', 'Hours', 'Minutes', 'Seconds', 'Milliseconds']) {
    defineProperty(dateProto, 'get' + k, { value: dateProto['getUTC' + k] });
    if (k !== 'Day') defineProperty(dateProto, 'set' + k, { value: dateProto['setUTC' + k] });
  }
  defineProperty(dateProto, 'getTimezoneOffset', { value: function () { return 0; } });
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const two = (n) => String(n).padStart(2, '0');
  defineProperty(dateProto, 'toString', { value: function () {
    if (isNaN(this.getTime())) return 'Invalid Date';
    return days[this.getUTCDay()] + ' ' + months[this.getUTCMonth()] + ' ' + two(this.getUTCDate()) + ' ' +
      this.getUTCFullYear() + ' ' + two(this.getUTCHours()) + ':' + two(this.getUTCMinutes()) + ':' + two(this.getUTCSeconds()) + ' GMT+0000';
  } });
  defineProperty(dateProto, 'toDateString', { value: function () {
    return isNaN(this.getTime()) ? 'Invalid Date' : days[this.getUTCDay()] + ' ' + months[this.getUTCMonth()] + ' ' + two(this.getUTCDate()) + ' ' + this.getUTCFullYear();
  } });
  defineProperty(dateProto, 'toLocaleDateString', { value: function () {
    return isNaN(this.getTime()) ? 'Invalid Date' : (this.getUTCMonth() + 1) + '/' + this.getUTCDate() + '/' + this.getUTCFullYear();
  } });
  defineProperty(dateProto, 'toLocaleTimeString', { value: function () {
    if (isNaN(this.getTime())) return 'Invalid Date';
    const h = this.getUTCHours();
    return (h % 12 || 12) + ':' + two(this.getUTCMinutes()) + ':' + two(this.getUTCSeconds()) + ' ' + (h < 12 ? 'AM' : 'PM');
  } });
  defineProperty(dateProto, 'toLocaleString', { value: function () {
    return isNaN(this.getTime()) ? 'Invalid Date' : this.toLocaleDateString() + ', ' + this.toLocaleTimeString();
  } });
  global.Date = ClDate;

  // Number formatting in en-US style on every engine (QuickJS has no Intl).
  const currencySymbols = { USD: '$', EUR: '€', GBP: '£', JPY: '¥', CNY: 'CN¥', INR: '₹', CAD: 'CA$', AUD: 'A$', KRW: '₩', BRL: 'R$', MXN: 'MX$' };
  function formatNumber(n, options) {
    n = Number(n);
    const o = options && typeof options === 'object' ? options : {};
    const style = o.style || 'decimal';
    const code = o.currency ? String(o.currency).toUpperCase() : 'USD';
    const zeroDecimals = code === 'JPY' || code === 'KRW';
    const defMin = style === 'currency' ? (zeroDecimals ? 0 : 2) : 0;
    const defMax = style === 'currency' ? defMin : style === 'percent' ? 0 : 3;
    let min = o.minimumFractionDigits ?? defMin;
    let max = o.maximumFractionDigits ?? Math.max(defMax, min);
    if (max < min) max = min;
    if (Number.isNaN(n)) return 'NaN';
    if (!Number.isFinite(n)) return n > 0 ? '∞' : '-∞';
    let v = style === 'percent' ? n * 100 : n;
    const negative = v < 0;
    let fixed = Math.abs(v).toFixed(max);
    if (fixed.includes('.')) {
      let end = fixed.length;
      const point = fixed.indexOf('.');
      while (end > point + 1 + min && fixed[end - 1] === '0') end--;
      if (end === point + 1) end = point;
      fixed = fixed.slice(0, end);
    }
    const point = fixed.indexOf('.');
    let whole = point < 0 ? fixed : fixed.slice(0, point);
    const fraction = point < 0 ? '' : fixed.slice(point);
    if (o.useGrouping !== false) whole = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    let body = whole + fraction;
    if (style === 'percent') body += '%';
    if (style === 'currency') body = (currencySymbols[code] ?? code + ' ') + body;
    return negative && Number(fixed) !== 0 ? '-' + body : body;
  }
  defineProperty(Number.prototype, 'toLocaleString', { value: function (_, options) { return formatNumber(this, options); } });
  defineProperty(Array.prototype, 'toLocaleString', { value: function () { return this.map((x) => x == null ? '' : x.toLocaleString()).join(','); } });
  // Text comparison that doesn't depend on the device's language: case
  // folded first, then by code units.
  defineProperty(String.prototype, 'localeCompare', { value: function (other) {
    const a = String(this), b = String(other);
    const la = a.toLowerCase(), lb = b.toLowerCase();
    if (la !== lb) return la < lb ? -1 : 1;
    return a === b ? 0 : a < b ? -1 : 1;
  } });
  if (typeof global.structuredClone !== 'function') {
    global.structuredClone = function structuredClone(v) { return plain(v, 'structuredClone()'); };
  }

  // Formatting helpers, the same on every engine.
  const fmt = freeze({
    number: (n, digits) => formatNumber(n, digits == null ? {} : { minimumFractionDigits: digits, maximumFractionDigits: digits }),
    currency: (n, code, digits) => formatNumber(n, digits == null ? { style: 'currency', currency: code || 'USD' } : { style: 'currency', currency: code || 'USD', minimumFractionDigits: digits, maximumFractionDigits: digits }),
    percent: (n, digits) => formatNumber(n, { style: 'percent', minimumFractionDigits: digits || 0, maximumFractionDigits: digits || 0 }),
    round: (n, digits) => { const f = Math.pow(10, digits || 0); return Math.round(Number(n) * f) / f; },
    date: (value, pattern) => {
      const d = value instanceof RealDate ? value : new ClDate(value);
      if (isNaN(d.getTime())) return '';
      const p = pattern || 'yyyy-MM-dd';
      const h = d.getUTCHours();
      const fullMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      const map = {
        yyyy: String(d.getUTCFullYear()), MMMM: fullMonths[d.getUTCMonth()], MMM: months[d.getUTCMonth()],
        MM: two(d.getUTCMonth() + 1), M: String(d.getUTCMonth() + 1), dd: two(d.getUTCDate()), d: String(d.getUTCDate()),
        EEE: days[d.getUTCDay()], HH: two(h), H: String(h), hh: two(h % 12 || 12), h: String(h % 12 || 12),
        mm: two(d.getUTCMinutes()), ss: two(d.getUTCSeconds()), a: h < 12 ? 'AM' : 'PM',
      };
      return p.replace(/yyyy|MMMM|MMM|MM|M|dd|d|EEE|HH|H|hh|h|mm|ss|a/g, (t) => map[t]);
    },
    duration: (seconds) => {
      let s = Math.max(0, Math.floor(Number(seconds) || 0));
      const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
      s %= 60;
      return h ? h + ':' + two(m) + ':' + two(s) : m + ':' + two(s);
    },
  });

  // Compiles a script without running it: '' when it's fine, else the
  // error as JSON.
  function check(text) {
    const req = JSONparse(text);
    try {
      compile(req.source, req.paramNames || []);
      return '';
    } catch (e) {
      const run = { headLength: 0 };
      try { run.headLength = compile('', req.paramNames || []).headLength; } catch (_) {}
      return JSONstringify(errorData(e, run));
    }
  }

  global.__cl_check = check;
  global.__cl_start = start;
  global.__cl_resume = resume;
  global.__cl_state = state;

  // --- Freeze the intrinsics so runs can't affect each other ----------
  // Assigning a property that a frozen prototype also has (`err.name =
  // 'X'`, `obj.toString = ...`) would throw. These properties become
  // accessors whose setter gives the object its own property instead.
  function allowOverride(obj, name) {
    const d = Object.getOwnPropertyDescriptor(obj, name);
    if (!d || !('value' in d) || !d.configurable) return;
    const value = d.value;
    defineProperty(obj, name, {
      get() { return value; },
      set(v) {
        if (this === obj) throw new TypeError('Cannot change a built-in: ' + name);
        defineProperty(this, name, { value: v, writable: true, enumerable: true, configurable: true });
      },
      enumerable: d.enumerable,
      configurable: false,
    });
  }
  for (const name of ['constructor', 'toString', 'valueOf', 'toLocaleString', 'toJSON']) allowOverride(Object.prototype, name);
  for (const E of [Error, TypeError, RangeError, ReferenceError, SyntaxError, URIError, EvalError]) {
    for (const name of ['name', 'message', 'toString', 'constructor']) allowOverride(E.prototype, name);
  }
  for (const name of ['toString', 'constructor']) allowOverride(Function.prototype, name);

  const seen = new Set();
  function harden(v) {
    if ((typeof v !== 'object' && typeof v !== 'function') || v === null || seen.has(v)) return;
    seen.add(v);
    for (const name of getOwnPropertyNames(v)) {
      const d = Object.getOwnPropertyDescriptor(v, name);
      if (d && 'value' in d) harden(d.value);
    }
    harden(getPrototypeOf(v));
    if (!isFrozen(v)) freeze(v);
  }
  for (const name of getOwnPropertyNames(global)) {
    if (name === 'globalThis' || name.startsWith('__cl_')) continue;
    try { harden(global[name]); } catch (_) {}
  }
  try { freeze(global); } catch (_) {}
})(globalThis);
''';
