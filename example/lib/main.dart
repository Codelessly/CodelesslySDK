import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Codelessly.instance.initialize(
    config: CodelesslyConfig(
      authToken: "cSlMIT93cj1lXkBuYk5QNmImSTUsTHw2MDQ4VkdlOCZFLHc7",
      isPreview: kDebugMode,
    ),
  );

  runApp(const MyStoryBookApp());
}

class MyStoryBookApp extends StatefulWidget {
  const MyStoryBookApp({super.key});

  @override
  State<MyStoryBookApp> createState() => _MyStoryBookAppState();
}

class _MyStoryBookAppState extends State<MyStoryBookApp> {
  Map<String, dynamic> licenseData = {'license': 'FREE'};

  @override
  Widget build(BuildContext context) => Storybook(
        initialStory: 'Hello World',
        showPanel: true,
        stories: [
          Story(
            name: 'Hello World',
            description: 'A simple hello world demo.',
            builder: (context) => MaterialApp(
              theme: Theme.of(context),
              home: Center(
                child: CodelesslyWidget(
                  layoutID: "0R0yB82iCD4RPZMZYOYZ",
                ),
              ),
            ),
          ),
          Story(
            name: 'License UI',
            description: "Demo of Codelessly's license UI.",
            builder: (context) => MaterialApp(
              theme: Theme.of(context),
              home: Center(
                child: CodelesslyWidget(
                  layoutID: "0R0yeUx1iGDe9kgW5xwn",
                  data: licenseData,
                  functions: {
                    'onFreeSelected': CodelesslyFunction((context, ref) {
                      licenseData['license'] = 'FREE';
                      setState(() {});
                    }),
                    'onProSelected': CodelesslyFunction((context, ref) {
                      licenseData['license'] = 'PRO';
                      setState(() {});
                    }),
                    'onBusinessSelected': CodelesslyFunction((context, ref) {
                      licenseData['license'] = 'BUSINESS';
                      setState(() {});
                    }),
                  },
                ),
              ),
            ),
          ),
          Story(
            name: 'Pricing UI',
            description: "Demo of Codelessly's pricing UI.",
            builder: (context) => MaterialApp(
              theme: Theme.of(context),
              home: Center(
                child: CodelesslyWidget(
                  layoutID: "0R0yedXWbqOrI_W7PBlo",
                ),
              ),
            ),
          ),
        ],
      );
}
