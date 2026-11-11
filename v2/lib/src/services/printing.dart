import 'dart:typed_data';

import 'printing_stub.dart'
    if (dart.library.js_interop) 'printing_web.dart'
    as platform;

/// Requests a print dialog. A true result means requested, never printed.
abstract interface class PrintService {
  Future<bool> printPng(Uint8List png);
}

class PlatformPrintService implements PrintService {
  const PlatformPrintService();
  @override
  Future<bool> printPng(Uint8List png) => platform.printPng(png);
}
