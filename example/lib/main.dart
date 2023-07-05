import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Codelessly.instance.initialize(
    config: const CodelesslyConfig(
      authToken: "fC9IZE0jL2kzME03bXEwIzE+LD04Z093ci1xMTJaJjMlI3hT",
      isPreview: false,
      automaticallyCollectCrashReports: false,
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
            builder: (context) => CodelesslyWidget(
              layoutID: "0R0PZ0qWewZyKqYrSjNq",
            ),
          ),
          Story(
            name: 'License UI',
            description: "Demo of Codelessly's license UI.",
            builder: (context) => CodelesslyWidget(
              layoutID: "0R0PYsM6kNpkBMr93LS7",
            ),
          ),
          Story(
            name: 'Pricing UI',
            description: "Demo of Codelessly's pricing UI.",
            builder: (context) => CodelesslyWidget(
              layoutID: "0R0PZFch5qUj1vhRPO_f",
            ),
          ),
        ],
      );
}
