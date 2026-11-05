# codelessly_quickjs

The sandboxed JavaScript engine that runs [Codelessly](https://codelessly.com) scripts on Android, iOS, macOS and Linux. It is [QuickJS](https://bellard.org/quickjs/) 2025-04-26, with a small C API (`src/codelessly_quickjs.h`) that `codelessly_sdk` calls through `dart:ffi`.

Add it to an app whose Codelessly project uses scripts:

```sh
flutter pub add codelessly_quickjs
```

Apps without scripts don't need it and don't pay for it. It adds about 0.6 MB per ABI (arm64 is similar to x86_64's 600 KB stripped).

On the web, scripts run in a Web Worker and this package isn't used.

## The sandbox

Each runtime has only the ECMAScript intrinsics: no `std` or `os` modules, so no files, network, timers or processes. Its heap and stack are limited, and an interrupt handler stops code that runs past its time budget. `codelessly_sdk` loads a driver into each runtime before any script. The driver removes everything that isn't standard ECMAScript, freezes the intrinsics, blocks code generation and `import()`, and exposes only the host APIs a script is granted.

## Layout

- `src/quickjs/`: QuickJS sources, unmodified (MIT, see `src/quickjs/LICENSE`).
- `src/codelessly_quickjs.{c,h}`: the C API (`cljs_new`, `cljs_eval`, `cljs_call`, ...).
- `src/CMakeLists.txt`: the build for Android and Linux (and for the SDK's tests, through `tool/build_quickjs.sh`).
- `ios/` and `macos/`: CocoaPods builds of the same sources, through forwarder files in `Classes/`.
