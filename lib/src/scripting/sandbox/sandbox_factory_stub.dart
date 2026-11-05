import 'script_sandbox.dart';

/// No engine on this platform.
ScriptSandbox createPlatformSandbox() =>
    throw const ScriptEngineUnavailable('Scripts can\'t run on this platform.');
