import 'dart:async';

/// The script tests run on the VM and in Chrome; the root config's golden
/// comparator uses dart:io, which Chrome can't compile, and these tests
/// have no goldens.
Future<void> testExecutable(FutureOr<void> Function() testMain) async =>
    testMain();
