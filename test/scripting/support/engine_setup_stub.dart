/// On the web, scripts run in a Web Worker: nothing to set up.
void setUpScriptEngine() {}

/// Why the tests that run scripts cannot run here: never, on the web.
const String? scriptEngineUnavailable = null;

/// The engine the tests run on.
const String scriptEngineName = 'web worker';
