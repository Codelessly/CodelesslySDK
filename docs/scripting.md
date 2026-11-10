# Scripts in the SDK

This page moved. Everything about scripts in SDK 20.x (adding the engine, the language, the host API, running
scripts from actions and formulas, errors, limits, and how the sandbox works) is in the developer guide:

**[Scripting](guide/10-scripting.md)**

The engine for Android, iOS, macOS and Linux is the
[`codelessly_quickjs`](https://github.com/Codelessly/CodelesslyQuickJS) package.

## SDK 10.x (legacy)

The legacy SDK at the repository root runs scripts the same way (the same driver and sandboxes). Two names differ:
scripts come with a layout in `SDKLayoutVariables.scripts`, project scripts under `kAppVariablesScope` and page
scripts under `kPageVariablesScope`, and `CodelesslyContext.scripts` holds them by name. Its tests are in
`test/scripting/` (`flutter test test/scripting`, and `--platform chrome` for the Web Worker engine).
