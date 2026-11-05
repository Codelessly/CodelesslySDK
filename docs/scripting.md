# Scripts in the SDK

Codelessly projects can include **scripts**: JavaScript that "Run script" actions (`RunScriptAction`) and formulas (`script.name(args)`) run in a sandbox. The language and host API reference is in the Editor repository (`docs/scripting_reference.md`), and the Editor MCP serves it as `scripts.catalog`.

## Adding the engine to an app

| Platform | Engine | What the app needs |
|---|---|---|
| Web | A dedicated Web Worker, made from a Blob URL | Nothing. If the page sets a Content Security Policy, it must allow `worker-src blob:` and `script-src 'unsafe-eval'`, which the worker needs. |
| Android, iOS, macOS, Linux | QuickJS 2025-04-26 through `dart:ffi` | `flutter pub add codelessly_quickjs` |
| Windows | none yet | Scripts fail with `EngineUnavailable`. |

An app without scripts doesn't add `codelessly_quickjs` and pays nothing for it. Without the package, a script fails with `EngineUnavailable` and a message saying what to add.

## How it works

```
RunScriptAction / script.name() in a formula
        │
ScriptRunner ── request {source, params, grants, vars, nodes, seed, now, scripts}
        │                                     ▲ state {status, events, logs, value | error}
ScriptSandbox  ── QuickJsSandbox (FFI, sync)  │
               └─ WorkerSandbox  (Worker, async)
        │
script_driver.dart (the same JavaScript in both engines)
```

- **`script_driver.dart`** is JavaScript that runs before any script.
  - It locks the global scope down: everything that isn't standard ECMAScript is deleted from the global object and its prototype chain.
  - It blocks code generation and `import()`.
  - It makes dates, `Math.random`, `Math.pow` and number formatting deterministic, and freezes every intrinsic.
  - It exposes the granted host APIs.
  - A run reports its variable writes and `app.*` calls as **events** in its state. The host applies them and resumes the run with the results, so neither engine needs callbacks into Dart.
- **`QuickJsSandbox`** runs each script in a QuickJS runtime with memory and stack limits and an interrupt deadline. A warm runtime is reused; one that hit a limit is thrown away.
- **`WorkerSandbox`** runs scripts in a Web Worker. A step that outruns its CPU budget gets the worker terminated and replaced.
- **`ScriptRunner`** builds the request: arguments with defaults, the variables and inputs a script may read, its grants, and a seed derived from the script and its arguments. It drives the run, applies writes through a `ScriptHost`, and returns a `ScriptRunResult`. It never throws.
  - **`FlutterScriptHost`** connects a run to a screen's variables, inputs and actions.
  - **`SampleScriptHost`** uses sample data, for the Editor and tests.
- **`ScriptFormulaCalls`** is what `script` resolves to in formulas. It gives read-only runs, synchronous on devices; on the web, `ScriptResults` rebuilds widgets when results arrive.
- **`ScriptCatalog`** describes the host API for the Editor, the MCP and these docs.

Scripts come with a layout in `SDKLayoutVariables.scripts`: project scripts under `kAppVariablesScope`, the layout's page scripts under `kPageVariablesScope`. `CodelesslyContext.scripts` holds them by name, page scripts winning.

## Testing

`test/scripting/` runs the same tests on the Dart VM, where scripts run in QuickJS (`flutter test test/scripting`), and in Chrome, where they run in a Web Worker (`flutter test --platform chrome test/scripting`).
- The VM run needs QuickJS built for the machine. The tests build it with `tool/build_quickjs.sh`, which needs CMake and a C compiler.
- The suite covers the host bindings, capabilities, sandbox escapes, limits, errors, the "Run script" action, formulas, and a determinism corpus whose output must be identical on both engines.
