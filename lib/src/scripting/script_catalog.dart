/// What scripts can use: the host APIs the driver gives them and the
/// helpers that behave the same on every engine. The Editor's completions,
/// the Editor MCP's `scripts.catalog` and the docs read this list.
library;

/// One function or value a script can use.
class ScriptApiEntry {
  /// How it's written, e.g. `vars.get(name)`.
  final String signature;

  /// What it gives back, e.g. `any` or `Promise<object>`.
  final String returns;

  /// What it does.
  final String description;

  /// The capability it needs, e.g. `variables.read`, or null.
  final String? capability;

  /// A short example.
  final String? example;

  /// Creates a [ScriptApiEntry].
  const ScriptApiEntry(
    this.signature,
    this.returns,
    this.description, {
    this.capability,
    this.example,
  });

  /// The object it belongs to, e.g. `vars`, or '' for a global.
  String get owner {
    final int dot = signature.indexOf('.');
    final int paren = signature.indexOf('(');
    return dot > 0 && (paren < 0 || dot < paren)
        ? signature.substring(0, dot)
        : '';
  }

  /// Its name, e.g. `get`.
  String get name {
    final String rest = owner.isEmpty
        ? signature
        : signature.substring(owner.length + 1);
    final int paren = rest.indexOf('(');
    return paren < 0 ? rest : rest.substring(0, paren);
  }

  /// The parameter names, e.g. `['name']`.
  List<String> get parameters {
    final int open = signature.indexOf('(');
    final int close = signature.lastIndexOf(')');
    if (open < 0 || close <= open + 1) return const [];
    return [
      for (final String p in signature.substring(open + 1, close).split(','))
        p.trim().replaceAll(RegExp(r'[?\[\]]'), ''),
    ];
  }

  /// The entry as JSON.
  Map<String, Object?> toJson() => {
    'signature': signature,
    'returns': returns,
    'description': description,
    if (capability != null) 'capability': capability,
    if (example != null) 'example': example,
  };
}

/// The host API and helpers available to every script.
abstract final class ScriptCatalog {
  /// The language, in a sentence.
  static const String language =
      'Modern JavaScript (ES2023) in strict mode, run in a sandbox: QuickJS '
      'on Android, iOS, macOS and Linux, a Web Worker on the web. The '
      "script's params are variables in it; it returns its result at its top "
      'level (or from `function main(...)`), and may use `await`.';

  /// What scripts can't do, and what to use instead.
  static const List<String> restrictions = [
    'No network, files, timers, storage or DOM: fetch, XMLHttpRequest, '
        'setTimeout, localStorage, window and document are undefined. Use '
        'the app.* host APIs (with their capabilities) instead.',
    'No code generation or loading: eval, new Function and import() are '
        'not allowed. Call other scripts with script.name(...).',
    'Built-ins are frozen (Array.prototype, Math, JSON, ...): change your '
        'own objects, not the language\'s.',
    'Dates are UTC on every device. Date.now() and new Date() need the '
        '"clock" capability; pass dates in as params to keep results '
        'repeatable.',
    'Math.random() is seeded per call (by the script and its arguments), so '
        'the same call gives the same numbers.',
    'No Intl: toLocaleString, localeCompare and fmt.* format in a fixed '
        'en-US style on every engine.',
    'Values going in and out are JSON data: objects, arrays, text, numbers, '
        'booleans and null.',
  ];

  /// The limits every run has.
  static const List<String> limits = [
    'timeoutMs (default 1000) of computing; time spent awaiting app.* calls '
        "doesn't count. Over it: LimitError (limit: time).",
    'memoryLimitMb (default 32) on devices. Over it: LimitError (limit: '
        'memory). The web enforces time only.',
    'Endless recursion: LimitError (limit: depth).',
    'At most 500 log lines of 2000 characters.',
  ];

  /// Every host API and helper.
  static const List<ScriptApiEntry> entries = [
    // Variables.
    ScriptApiEntry(
      'vars.get(name)',
      'any',
      "The value of the screen's variable [name] (app, page or screen variable).",
      capability: 'variables.read',
      example: 'const count = vars.get("count");',
    ),
    ScriptApiEntry(
      'vars.has(name)',
      'boolean',
      'Whether the screen has a variable named [name].',
      capability: 'variables.read',
    ),
    ScriptApiEntry(
      'vars.all()',
      'object',
      'Every variable, by name.',
      capability: 'variables.read',
    ),
    ScriptApiEntry(
      'vars.set(name, value)',
      'any',
      'Sets the variable [name] to [value] (JSON data) and returns it. Later vars.get reads see it; '
          'the app applies it, in order, before the next app.* call and when the script ends.',
      capability: 'variables.write',
      example: 'vars.set("total", total);',
    ),
    // Inputs.
    ScriptApiEntry(
      'nodes.value(id)',
      'any',
      'The value of the input node [id] (a text field\'s text, a checkbox\'s state, ...), or null.',
      capability: 'nodes.read',
      example: 'const email = nodes.value("emailField");',
    ),
    ScriptApiEntry(
      'nodes.all()',
      'object',
      'Every input value, by node id.',
      capability: 'nodes.read',
    ),
    // The app.
    ScriptApiEntry(
      'app.navigate(screen, params?)',
      'Promise<null>',
      'Navigates to [screen] (a screen\'s name or id), passing [params] as its route params.',
      capability: 'navigation',
      example: 'await app.navigate("Receipt", {id});',
    ),
    ScriptApiEntry(
      'app.back(result?)',
      'Promise<null>',
      'Goes back, or closes the open dialog, handing back [result].',
      capability: 'navigation',
    ),
    ScriptApiEntry(
      'app.callApi(name, inputs?)',
      'Promise<{status, ok, body, headers}>',
      "Calls the project's API [name] with [inputs] for its parameters. [body] is parsed JSON when "
          'the response is JSON.',
      capability: 'api',
      example: 'const r = await app.callApi("Weather", {city});\nif (!r.ok) throw new Error(r.status);',
    ),
    ScriptApiEntry(
      'app.cloudData(request)',
      'Promise<any>',
      'Runs a Cloud Data action described by [request] (its JSON fields, e.g. {operation, '
          'collection, ...}) and returns its result.',
      capability: 'cloud',
    ),
    ScriptApiEntry(
      'app.runAction(action)',
      'Promise<any>',
      'Runs any action from its JSON (e.g. {type: "showDialog", destinationId}) and returns the '
          "action's \${result}.",
      capability: 'actions',
    ),
    ScriptApiEntry(
      'app.toast(text)',
      'Promise<null>',
      'Shows a toast.',
      capability: 'actions',
    ),
    ScriptApiEntry(
      'app.delay(ms)',
      'Promise<null>',
      'Waits [ms] milliseconds (at most 60000). The run stays one transaction: no other script changes '
          'variables meanwhile.',
      capability: 'actions',
    ),
    ScriptApiEntry(
      'app.yield(ms)',
      'Promise<null>',
      'Waits [ms] milliseconds, letting other scripts change variables meanwhile (a cancel button, a timer); '
          'vars.get afterwards reads their changes. For long runs that show progress.',
      capability: 'actions',
    ),
    // Other scripts.
    ScriptApiEntry(
      'script.<name>(...args)',
      'Promise<any>',
      "Runs another of the project's scripts with its params in order, in this run (same "
          'capabilities and limits).',
      example: 'const cents = await script.toCents(amount);',
    ),
    ScriptApiEntry(
      'params',
      'object',
      "The script's params by name (they're also variables).",
    ),
    // Logging.
    ScriptApiEntry(
      'console.log(...values)',
      'undefined',
      "Logs to the run's console (also console.info, warn, error and debug).",
    ),
    // Formatting.
    ScriptApiEntry(
      'fmt.number(n, digits?)',
      'string',
      '1234567.891 → "1,234,567.891"; with digits, exactly that many decimals.',
    ),
    ScriptApiEntry(
      'fmt.currency(n, code?, digits?)',
      'string',
      '1234.5 → "\$1,234.50"; code is an ISO currency (default USD).',
    ),
    ScriptApiEntry('fmt.percent(n, digits?)', 'string', '0.256 → "26%".'),
    ScriptApiEntry(
      'fmt.round(n, digits?)',
      'number',
      'Rounds half up to [digits] decimals: fmt.round(2.675, 2) → 2.68.',
    ),
    ScriptApiEntry(
      'fmt.date(value, pattern?)',
      'string',
      'Formats a date (ISO text, epoch ms or Date) in UTC: yyyy, MMMM, MMM, MM, M, dd, d, EEE, HH, H, hh, h, mm, ss, a. '
          'Default "yyyy-MM-dd".',
    ),
    ScriptApiEntry(
      'fmt.duration(seconds)',
      'string',
      '3725 → "1:02:05", 125 → "2:05".',
    ),
  ];

  /// The catalog as JSON, for the Editor MCP.
  static Map<String, Object?> toJson() => {
    'language': language,
    'restrictions': restrictions,
    'limits': limits,
    'capabilities': const {
      'variables.read': 'vars.get, vars.has, vars.all',
      'variables.write': 'vars.set',
      'nodes.read': 'nodes.value, nodes.all',
      'navigation': 'app.navigate, app.back',
      'api': 'app.callApi',
      'cloud': 'app.cloudData',
      'actions': 'app.runAction, app.toast, app.delay, app.yield',
      'clock': 'Date.now(), new Date()',
    },
    'api': [for (final ScriptApiEntry e in entries) e.toJson()],
    'formulas':
        'Formulas call scripts as script.name(args), with the params in order: '
        r'${= script.payment(amount, rate, 30)}. Only the read capabilities apply there '
        '(variables.read, nodes.read, clock). On the web the value arrives after the script runs.',
    'actions':
        'A "Run script" action (type runScript) runs a script with arguments; its result is '
        r'${result} for the actions after it (and can be stored with resultVariable). If it fails, its '
        r'onError actions run with ${result.error} = {type, message, line, column}.',
  };
}
