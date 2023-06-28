import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Codelessly.instance.initialize(
    config: const CodelesslyConfig(
      authToken: "LCVyNTxyLCVxQXh3WDc5MFowLjApQXJfWyNdSnlAQjphLyN1",
      isPreview: false,
      automaticallyCollectCrashReports: false,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codelessly SDK Example',
      home: SafeArea(
        child: CodelesslyWidget(
          layoutID: "0Qz5TaUXGRBrc53IZW7M",
        ),
      ),
    );
  }
}
