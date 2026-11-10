// The Codelessly SDK example.
//
// By default it runs offline: the published projects are bundles shipped
// with the app (assets) or built in memory. Two more ways to load a project
// are here, behind `--dart-define`s:
//
//   flutter run                                   # offline (default)
//   flutter run --dart-define=CODELESSLY_SLUG=<your project's slug>
//   flutter run --dart-define=CODELESSLY_TOKEN=<your project's token>
//
// See `openProject` for the three.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
// Only for the project token mode (`codelesslyWithToken`).
import 'package:codelessly_sdk_v2/firebase.dart';
import 'package:flutter/material.dart';

import 'hello_bundle.dart';

/// A published project's slug: its publish is one file, fetched over HTTP.
const String slug = String.fromEnvironment('CODELESSLY_SLUG');

/// A project's token: its publish is read from Codelessly's Firebase, and
/// each new publish reaches the running app (live updates).
const String token = String.fromEnvironment('CODELESSLY_TOKEN');

/// The bundle asset shown by default: a project of several screens, each
/// with mobile, tablet and desktop canvases.
const String bundleAsset = 'assets/rigcheck.json.gz';

/// Opens the project the app shows as a whole.
Future<Codelessly> openProject({CodelesslyConfig config = const CodelesslyConfig()}) async {
  // 1. A project token: Firestore, with live updates.
  if (token.isNotEmpty) return codelesslyWithToken(token, config: config);

  // 2. A published slug: one HTTP request, no Firebase.
  if (slug.isNotEmpty) return Codelessly(config: config.copyWith(slug: slug));

  // 3. A bundle shipped with the app: offline.
  return Codelessly.asset(bundleAsset, config: config);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Codelessly SDK example',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF4B6CE5)),
        home: const ExampleHome(),
      );
}

/// The two ways an app uses the SDK.
class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Codelessly SDK')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Embedded widget'),
              subtitle: const Text('One layout inside a Flutter screen, with data, a function and a controller'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EmbeddedExample())),
            ),
            ListTile(
              leading: const Icon(Icons.phone_iphone),
              title: const Text('Whole app'),
              subtitle: Text(
                token.isNotEmpty
                    ? 'A project token (Firebase, live updates)'
                    : slug.isNotEmpty
                        ? 'The slug "$slug" (HTTP)'
                        : 'A bundled asset (offline)',
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WholeAppExample())),
            ),
          ],
        ),
      );
}

/// One layout inside a screen the app builds itself.
///
/// The layout reads the app's data (`${data.name}`), was opened with params
/// (`${route.source}`), and its button calls a function of the app
/// (`onTap`). The controller reads and changes the screen's variables.
class EmbeddedExample extends StatefulWidget {
  const EmbeddedExample({super.key});

  @override
  State<EmbeddedExample> createState() => _EmbeddedExampleState();
}

class _EmbeddedExampleState extends State<EmbeddedExample> {
  late final Codelessly codelessly = Codelessly.fromBundle(
    helloBundle(),
    config: CodelesslyConfig(
      // What "call function" actions call, by name.
      functions: {
        'onTap': (context, params) {
          ScaffoldMessenger.of(this.context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('The layout called onTap with ${params['count']}')));
          return null;
        },
      },
    ),
  );
  final controller = CodelesslyWidgetController();
  String name = 'Flutter';

  @override
  void dispose() {
    controller.dispose();
    codelessly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Embedded widget')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: name,
              decoration: const InputDecoration(labelText: 'Your name (the layout reads data.name)'),
              onChanged: (value) => setState(() => name = value),
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              // In a scroll view the height is unbounded: this canvas hugs
              // its content, so it takes the height it needs.
              child: CodelesslyWidget(
                codelessly: codelessly,
                controller: controller,
                layoutId: helloLayoutId,
                data: {'name': name},
                params: const {'source': 'the example'},
                loadingBuilder: (_) => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (_, error) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
              ),
            ),
            const SizedBox(height: 16),
            // The app changes the screen's state from outside.
            OutlinedButton(
              onPressed: () => controller.setVariable('count', 0),
              child: const Text('Reset the layout\'s count'),
            ),
          ],
        ),
      );
}

/// A published project as a whole app: its entry screen first, its own
/// navigation between screens, each screen at its URL path.
class WholeAppExample extends StatefulWidget {
  const WholeAppExample({super.key});

  @override
  State<WholeAppExample> createState() => _WholeAppExampleState();
}

class _WholeAppExampleState extends State<WholeAppExample> {
  late final Future<Codelessly> codelessly = openProject();

  @override
  void dispose() {
    codelessly.then((c) => c.dispose(), onError: (_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Codelessly>(
        future: codelessly,
        builder: (context, snapshot) {
          final project = snapshot.data;
          if (snapshot.hasError) return Scaffold(body: CodelesslyErrorScreen(error: snapshot.error!));
          if (project == null) return const Scaffold(body: CodelesslyLoadingScreen());
          // The project's screens get a navigator of their own; resize the
          // window to see each screen pick its canvas by breakpoint.
          return Navigator(
            onGenerateRoute: CodelesslyWidget.onGenerateRoute(
              project,
              template: CodelesslyWidget(
                loadingBuilder: (_) => const Scaffold(body: CodelesslyLoadingScreen()),
                errorBuilder: (_, error) => Scaffold(body: CodelesslyErrorScreen(error: error)),
              ),
            ),
          );
        },
      );
}
