// The storyboard's entry point (the template's pattern for an app: the
// storyboard in lib/storyboard, started from lib/main_storyboard.dart).
//
//   flutter run -d chrome -t lib/main_storyboard.dart
import 'package:flutter/widgets.dart';

import 'skip/skip_storyboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SkipStoryboardApp());
}
