import 'dart:developer';

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

class MyStoryBookApp extends StatelessWidget {
  const MyStoryBookApp({super.key});

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
                  layoutID: "0R0yRfzR23SQfDGrbg3h",
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
                  functions: {
                    'onFreeSelected': (context, ref) {
                      log('Free license selected');
                    },
                    'onProSelected': (context, ref) {
                      log('Pro license selected');
                    },
                    'onBusinessSelected': (context, ref) {
                      log('Business license selected');
                    },
                    'onUpgradeToPro': (context, ref) {
                      log('Upgrade to Pro license');
                    },
                    'onUpgradeToBusiness': (context, ref) {
                      log('Upgrade to Business license');
                    },
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
