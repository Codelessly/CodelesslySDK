/// The QuickJS engine that runs Codelessly scripts on Android, iOS, macOS
/// and Linux.
///
/// This package only ships the native library; `codelessly_sdk` loads it
/// with `dart:ffi` when a script runs. Add the package to an app whose
/// Codelessly project uses scripts:
///
/// ```sh
/// flutter pub add codelessly_quickjs
/// ```
///
/// On the web, scripts run in a Web Worker and this package isn't needed.
library;

/// The QuickJS release this package builds.
const String quickJsVersion = '2025-04-26';
