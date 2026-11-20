// The Codelessly SDK example.
//
// This app uses no Material: it is a plain `WidgetsApp`, and the SDK needs
// nothing more. The same screens under a `MaterialApp` are in
// `main_material.dart` (`flutter run -t lib/main_material.dart`).
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
import 'package:codelessly_sdk/codelessly_sdk.dart';
// Only for the project token mode (`codelesslyWithToken`).
import 'package:codelessly_sdk/firebase.dart';
import 'package:flutter/widgets.dart';

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

// The example's own look: a handful of colors and text styles.
const Color _ink = Color(0xFF14181F);
const Color _muted = Color(0xFF5B6472);
const Color _paper = Color(0xFFFFFFFF);
const Color _line = Color(0xFFDDE1E8);
const Color _accent = Color(0xFF4B6CE5);
const TextStyle _body = TextStyle(color: _ink, fontSize: 15, height: 1.35, decoration: TextDecoration.none);
const TextStyle _small = TextStyle(color: _muted, fontSize: 13, height: 1.35, decoration: TextDecoration.none);
const TextStyle _title =
    TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w600, decoration: TextDecoration.none);

/// A screen of the example pushed on the app's navigator.
Route<T> examplePage<T>(WidgetBuilder builder) =>
    PageRouteBuilder<T>(pageBuilder: (context, _, _) => builder(context));

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => WidgetsApp(
        title: 'Codelessly SDK example',
        color: _accent,
        textStyle: _body,
        // What `home` is shown in: a `WidgetsApp` has no page route of its own.
        pageRouteBuilder: <T>(settings, builder) =>
            PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
        home: const ExampleHome(),
      );
}

/// A screen of the example: a title bar (with a way back when there is
/// one) over [child], on paper.
class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _paper,
        child: DefaultTextStyle(
          style: _body,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      if (Navigator.of(context).canPop()) ...[
                        ExampleButton(label: 'Back', onPressed: () => Navigator.of(context).pop()),
                        const SizedBox(width: 12),
                      ],
                      Expanded(child: Text(title, style: _title)),
                    ]),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
}

/// A button of the example's own: a label in an outlined box.
class ExampleButton extends StatelessWidget {
  const ExampleButton({super.key, required this.label, required this.onPressed, this.selected = false});

  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? _accent : _paper,
              border: Border.all(color: selected ? _accent : _line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(label, style: _body.copyWith(color: selected ? _paper : _ink, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      );
}

/// The two ways an app uses the SDK.
class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) => ExamplePage(
        title: 'Codelessly SDK',
        child: ListView(
          children: [
            _HomeRow(
              title: 'Embedded widget',
              subtitle: 'One layout inside a Flutter screen, with data, a function and a controller',
              onTap: () => Navigator.of(context).push(examplePage<void>((_) => const EmbeddedExample())),
            ),
            _HomeRow(
              title: 'Whole app',
              subtitle: token.isNotEmpty
                  ? 'A project token (Firebase, live updates)'
                  : slug.isNotEmpty
                      ? 'The slug "$slug" (HTTP)'
                      : 'A bundled asset (offline)',
              onTap: () => Navigator.of(context).push(examplePage<void>((_) => const WholeAppExample())),
            ),
          ],
        ),
      );
}

class _HomeRow extends StatelessWidget {
  const _HomeRow({required this.title, required this.subtitle, required this.onTap});

  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _small),
                ],
              ),
            ),
          ),
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
          setState(() => called = 'The layout called onTap with ${params['count']}');
          return null;
        },
      },
    ),
  );
  final controller = CodelesslyWidgetController();
  String name = 'Flutter';

  /// What the layout last told the app.
  String called = 'The layout has not called the app yet';

  @override
  void dispose() {
    controller.dispose();
    codelessly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
        title: 'Embedded widget',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Your name (the layout reads data.name)', style: _small),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final choice in const ['Flutter', 'Ada', 'Grace'])
                ExampleButton(label: choice, selected: choice == name, onPressed: () => setState(() => name = choice)),
            ]),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // In a scroll view the height is unbounded: this canvas hugs
                // its content, so it takes the height it needs.
                child: CodelesslyWidget(
                  codelessly: codelessly,
                  controller: controller,
                  layoutId: helloLayoutId,
                  data: {'name': name},
                  params: const {'source': 'the example'},
                  loadingBuilder: (_) => const SizedBox(height: 160, child: CodelesslyLoadingScreen()),
                  errorBuilder: (_, error) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(called, style: _small),
            const SizedBox(height: 16),
            // The app changes the screen's state from outside.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExampleButton(
                label: 'Reset the layout\'s count',
                onPressed: () => controller.setVariable('count', 0),
              ),
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
  Widget build(BuildContext context) => ColoredBox(
        color: _paper,
        child: FutureBuilder<Codelessly>(
          future: codelessly,
          builder: (context, snapshot) {
            final project = snapshot.data;
            if (snapshot.hasError) return CodelesslyErrorScreen(error: snapshot.error!);
            if (project == null) return const CodelesslyLoadingScreen();
            // The project's screens get a navigator of their own; resize the
            // window to see each screen pick its canvas by breakpoint.
            return Navigator(onGenerateRoute: CodelesslyWidget.onGenerateRoute(project));
          },
        ),
      );
}
