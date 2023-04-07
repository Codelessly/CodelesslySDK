import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';

const String authToken = 'UnJ5XU1fR0Z5JUU1MSpWamUvJj4wYzlzVDUmazxZIUA5Jkxr';
const String layoutID = '0Qq3UXthyzNKDS35vgek';

// METHOD 1
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Codelessly.initializeSDK(
    config: const CodelesslyConfig(
      authToken: authToken,
      automaticallyCollectCrashReports: false,
      isPreview: true,
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
      debugShowCheckedModeBanner: false,
      home: SafeArea(
        child: CodelesslyWidget(
          layoutID: layoutID,
          isPreview: true,
          // config: const CodelesslyConfig(
          //   authToken: 'UnJ5XU1fR0Z5JUU1MSpWamUvJj4wYzlzVDUmazxZIUA5Jkxr',
          // ),
        ),
      ),
    );
  }
}

// METHOD 2
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(
//     CodelesslyWidget(
//       layoutID: layoutID,
//       config: const CodelesslyConfig(
//         authToken: authToken,
//       ),
//     ),
//   );
// }
//
// METHOD 3
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   final Codelessly codelessly = Codelessly(
//     config: const CodelesslyConfig(
//       authToken: authToken,
//     ),
//   );
//
//   // Can be run at any point in time.
//   codelessly.init();
//
//   runApp(CodelesslyWidget(
//     codelessly: codelessly,
//     layoutID: layoutID,
//   ));
// }
