import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Codelessly.instance.initialize(
    config: CodelesslyConfig(
      authToken: "cSlMIT93cj1lXkBuYk5QNmImSTUsTHw2MDQ4VkdlOCZFLHc7", // Replace with yours
      isPreview: kDebugMode,
      preload: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CodelesslyLayoutScreen(),
    );
  }
}

class CodelesslyLayoutScreen extends StatelessWidget {
  const CodelesslyLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: CodelesslyWidget(
          layoutID: "0Rxvyp379pTkaqMd0xRj", // Your actual layout ID
          loadingBuilder: (context) => Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
