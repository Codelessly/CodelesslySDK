// The notation playground as an app of its own: NotationPlayground on a
// soft_saas_ui app, with a light / dark toggle in its header.
//
//   flutter run -d chrome
//
// A link can open on a sample, a design system and a theme:
// ?sample=approval_card&system=harbor&theme=dark
import 'package:flutter/widgets.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

import 'notation_playground.dart';

export 'notation_playground.dart';

void main() => runApp(PlaygroundApp(parameters: Uri.base.queryParameters));

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key, this.loadAsset, this.parameters = const <String, String>{}});

  /// Reads an asset (the app's bundle by default; a test gives its own).
  final PlaygroundAssetLoader? loadAsset;

  /// The page's query parameters: `sample`, `system` and `theme`.
  final Map<String, String> parameters;

  @override
  State<PlaygroundApp> createState() => _PlaygroundAppState();
}

class _PlaygroundAppState extends State<PlaygroundApp> {
  late SoftSaaSThemeMode _mode = switch (widget.parameters['theme']) {
    'dark' => SoftSaaSThemeMode.dark,
    'light' => SoftSaaSThemeMode.light,
    _ => SoftSaaSThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    return SoftSaaSApp(
      title: 'Notation playground',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      // Copies and the previewed UI's toasts show here.
      builder: (BuildContext context, Widget? child) => SoftSaaSToaster(child: child!),
      home: SoftSaaSScaffold(
        body: Builder(
          builder: (BuildContext context) => NotationPlayground(
            loadAsset: widget.loadAsset,
            initialSample: widget.parameters['sample'],
            initialSystem: widget.parameters['system'],
            actions: <Widget>[
              SoftSaaSThemeToggle(
                key: const ValueKey<String>('playground-theme'),
                onPressed: () => setState(
                  () => _mode = SoftSaaSTheme.isDark(context) ? SoftSaaSThemeMode.light : SoftSaaSThemeMode.dark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
