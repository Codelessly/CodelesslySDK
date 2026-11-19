// The Codelessly SDK example under a `MaterialApp`:
//
//   flutter run -t lib/main_material.dart
//
// The screens are the ones of `main.dart`. The SDK takes nothing from the
// Material theme given here: a project looks the same in both apps.
import 'package:flutter/material.dart';

import 'main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialExampleApp());
}

class MaterialExampleApp extends StatelessWidget {
  const MaterialExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Codelessly SDK example',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF4B6CE5)),
        home: const ExampleHome(),
      );
}
