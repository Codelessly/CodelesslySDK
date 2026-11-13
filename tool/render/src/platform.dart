// Platform services the render command answers itself: a headless test
// binding has no engine behind its platform channel, so a call on it (the
// clipboard) never completes, and an action chain that awaits one stops
// there without an error.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers the platform channel's clipboard calls from memory, as a device
/// would; other calls on the channel succeed with no result. Returns what
/// removes it.
void Function() installMemoryClipboard(WidgetTester tester) {
  String? text;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        text = (call.arguments as Map?)?['text'] as String?;
        return null;
      case 'Clipboard.getData':
        return text == null ? null : {'text': text};
      case 'Clipboard.hasStrings':
        return {'value': text?.isNotEmpty ?? false};
    }
    return null;
  });
  return () => messenger.setMockMethodCallHandler(SystemChannels.platform, null);
}
