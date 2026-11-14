// The generated Skip screens as a running app: a phone in the middle, the
// person to show it for above, and what the screens told the app beside it.
// The frame is soft_saas_ui; what is in the phone is drawn by the SDK from
// the generated documents under the Skip design system.
//
//   flutter run -d chrome
import 'package:codelessly_sdk/codelessly_sdk.dart' show CodelesslyView;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

import 'skip_app.dart';

void main() => runApp(const ShellApp());

class ShellApp extends StatelessWidget {
  const ShellApp({super.key, this.loadAsset});
  final Future<String> Function(String key)? loadAsset;

  @override
  Widget build(BuildContext context) => SoftSaaSApp(
        title: 'Skip, generated',
        debugShowCheckedModeBanner: false,
        themeMode: SoftSaaSThemeMode.light,
        home: SoftSaaSScaffold(body: Shell(loadAsset: loadAsset ?? rootBundle.loadString)),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.loadAsset});
  final Future<String> Function(String key) loadAsset;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final SkipApp app = SkipApp(widget.loadAsset)..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    app.start();
  }

  @override
  void dispose() {
    app
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = SoftSaaSTheme.brightnessOf(context);
    final session = app.session;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: SoftSaaSTokens.pageGutter),
        decoration: BoxDecoration(
          color: SoftSaaSTokens.primaryBackground(b),
          border: Border(bottom: BorderSide(color: SoftSaaSTokens.primaryBorder(b))),
        ),
        child: Row(children: [
          Text('Skip, generated', style: SoftSaaSTypography.sectionTitle(b)),
          const SizedBox(width: 16),
          SoftSaaSSegmentedControl<String>(
            key: const Key('person'),
            options: const [
              SegmentedControlOption(value: 'beginner', label: 'Beginner'),
              SegmentedControlOption(value: 'kid', label: 'Kid'),
              SegmentedControlOption(value: 'athlete', label: 'Athlete'),
            ],
            value: app.person,
            onChanged: app.choose,
          ),
          const SizedBox(width: 16),
          SoftSaaSSegmentedControl<String>(
            key: const Key('screen'),
            options: const [
              SegmentedControlOption(value: 'home', label: 'Home'),
              SegmentedControlOption(value: 'history', label: 'History'),
              SegmentedControlOption(value: 'session', label: 'Session'),
            ],
            value: app.screen,
            onChanged: app.open,
          ),
          const Spacer(),
          Flexible(
            child: Text(
              'Streak ${app.data['streak'] ?? '-'} · ${(app.data['sessions'] as List?)?.length ?? 0} sessions in the store',
              key: const Key('store'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SoftSaaSTypography.caption(b),
            ),
          ),
        ]),
      ),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ColoredBox(
              color: SoftSaaSTokens.secondaryBackground(b),
              child: Center(
                child: session == null
                    ? const SoftSaaSSpinner()
                    : Container(
                        width: 390,
                        constraints: const BoxConstraints(maxHeight: 844),
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: SoftSaaSTokens.primaryBorder(b)),
                          color: SoftSaaSTokens.primaryBackground(b),
                        ),
                        child: SingleChildScrollView(child: CodelesslyView(key: ObjectKey(session), session: session)),
                      ),
              ),
            ),
          ),
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: SoftSaaSTokens.primaryBackground(b),
              border: Border(left: BorderSide(color: SoftSaaSTokens.primaryBorder(b))),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SoftSaaSPaneToolbar(title: 'What the screens told the app'),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(SoftSaaSTokens.cardPadding), children: [
                  if (app.log.isEmpty) Text('Tap in the phone. Each action a screen fires is listed here.', style: SoftSaaSTypography.caption(b)),
                  for (final l in app.log)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${l.screen}: ${l.text}', style: SoftSaaSTypography.bodySecondary(b)),
                    ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
