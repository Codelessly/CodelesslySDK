// Shows a published Codelessly project, migrated from v1, with the v2 SDK.
//
// The publish comes from a bundle asset (offline). Navigation actions move
// between screens; resize the window to see each screen pick its mobile,
// tablet or desktop canvas.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// The projects the app can show: a name and its bundle asset.
const Map<String, String> projects = {
  'Rigcheck (responsive)': 'assets/rigcheck.json.gz',
  'Linewatch': 'assets/linewatch.json.gz',
};

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String project = projects.keys.first;
  late Codelessly codelessly = _open(project);

  Codelessly _open(String name) => Codelessly.asset(
        projects[name]!,
        config: const CodelesslyConfig(
          // Runs navigation and links until an actions runtime is set.
          actions: NavigationActionRunner(),
        ),
      );

  void _switch(String name) {
    if (name == project) return;
    final old = codelessly;
    setState(() {
      project = name;
      codelessly = _open(name);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    codelessly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // A new navigator for each project.
      key: ValueKey(project),
      title: 'Codelessly SDK v2',
      debugShowCheckedModeBanner: false,
      // Every screen, with the project menu over it.
      onGenerateRoute: CodelesslyWidget.onGenerateRoute(
        codelessly,
        template: CodelesslyWidget(
          layoutBuilder: (context, layout) => Stack(
            children: [
              Positioned.fill(child: layout),
              Positioned(right: 12, bottom: 12, child: _ProjectMenu(current: project, onSelected: _switch)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu({required this.current, required this.onSelected});

  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      shape: const StadiumBorder(),
      child: PopupMenuButton<String>(
        tooltip: 'Project',
        initialValue: current,
        onSelected: onSelected,
        itemBuilder: (_) => [for (final p in projects.keys) PopupMenuItem(value: p, child: Text(p))],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.layers_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(current, style: const TextStyle(color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
