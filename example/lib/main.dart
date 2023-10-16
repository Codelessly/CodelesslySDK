import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Codelessly.instance.initialize(
    config: CodelesslyConfig(
      authToken: "cSlMIT93cj1lXkBuYk5QNmImSTUsTHw2MDQ4VkdlOCZFLHc7",
      isPreview: kDebugMode,
      preload: false,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, dynamic> licenseData = {'license': 'FREE'};

  @override
  Widget build(BuildContext context) => Storybook(
        initialStory: 'Hello World',
        showPanel: true,
        wrapperBuilder: (context, child) {
          return MaterialApp(
            home: child,
          );
        },
        stories: [
          Story(
              name: 'Hello World',
              builder: (context) {
                return CodelesslyWidget(
                  layoutID: "0R0yRfzR23SQfDGrbg3h",
                  loadingBuilder: (context) {
                    return const CupertinoActivityIndicator();
                  },
                );
              }),
          Story(
              name: 'License UI',
              builder: (context) {
                return CodelesslyWidget(
                  layoutID: "0R0yeUx1iGDe9kgW5xwn",
                  data: licenseData,
                  functions: {
                    'onFreeSelected': (context, reference, params) {
                      licenseData['license'] = 'FREE';
                      setState(() {});
                    },
                    'onProSelected': (context, reference, params) {
                      licenseData['license'] = 'PRO';
                      setState(() {});
                    },
                    'onBusinessSelected': (context, reference, params) {
                      licenseData['license'] = 'BUSINESS';
                      setState(() {});
                    },
                  },
                  loadingBuilder: (context) {
                    return const CupertinoActivityIndicator();
                  },
                );
              }),
          Story(
              name: 'Pricing UI',
              builder: (context) {
                return CodelesslyWidget(
                  layoutID: "0R0yedXWbqOrI_W7PBlo",
                  loadingBuilder: (context) {
                    return const CupertinoActivityIndicator();
                  },
                );
              }),
          Story(
            name: 'Pricing Card',
            builder: (context) {
              return CodelesslyWidget(
                layoutID: '0R1xmqF5lXMr6LpLA9h5',
                loadingBuilder: (context) {
                  return const CupertinoActivityIndicator();
                },
              );
            },
          ),
          Story(
            name: 'Fruit Product Card',
            builder: (context) {
              return CodelesslyWidget(
                layoutID: '0R5hf4ABTQmzDb6e8XyR',
                data: const {
                  'name': 'Mango',
                  'price': 5.99,
                  'count': 1,
                  'description':
                      'Mangos are versatile fruits that can be enjoyed in many ways. You can eat them fresh as a snack or dessert, or add them to salads, smoothies, salsas, curries, cakes, pies, and more. You can also make mango juice, jam, chutney, or pickle.\n\nMangos are a great way to add some tropical flavor and nutrition to your diet.'
                },
                loadingBuilder: (context) {
                  return const CupertinoActivityIndicator();
                },
              );
            },
          ),
        ],
      );
}
