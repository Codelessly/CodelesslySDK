// A playground for the compact notation: type it on the left, see it
// rendered on the right as you type, under any of the bundled design
// systems. Below the preview: what the parser could not read (with its
// line), what the UI told the app (emit, toast), and the document the
// notation expands to.
//
// Its own frame is soft_saas_ui, the design system CodelesslyEditor is built
// with (the app, the split view, pane toolbars, the code field, selects and
// segmented controls), so [Playground] can be placed in the Editor as it is.
//
//   flutter run -d chrome        (or any device)
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart' show CodelesslyView, UiSession;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:soft_saas_ui/soft_saas_ui.dart';

/// The design systems bundled as assets (tool/bundle.sh).
const designSystems = ['ssui', 'paper', 'harbor'];

/// The samples under assets/samples, first the one shown at start.
const samples = [
  'start_here',
  'approval_card',
  'elicitation_form',
  'job_progress',
  'data_table',
  'comparison',
  'schedule',
  'quota_banner',
  'voice_conversation',
];

void main() => runApp(const PlaygroundApp());

class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({super.key, this.loadAsset});

  /// Reads an asset (the app's bundle by default; a test gives its own).
  final Future<String> Function(String key)? loadAsset;

  @override
  Widget build(BuildContext context) => SoftSaaSApp(
    title: 'Codelessly playground',
    debugShowCheckedModeBanner: false,
    themeMode: SoftSaaSThemeMode.light,
    home: SoftSaaSScaffold(body: Playground(loadAsset: loadAsset ?? rootBundle.loadString)),
  );
}

/// What one reading of the editor's text gave.
class Reading {
  Reading(this.session, this.issues, this.document, this.notationChars);
  final UiSession session;
  final List<NotationIssue> issues;
  final Map<String, Object?> document;
  final int notationChars;

  int get nodes => (document['nodes'] as Map?)?.length ?? 0;
  late final String json = const JsonEncoder.withIndent(' ').convert(document);
  late final int jsonChars = jsonEncode(document).length;
}

/// Reads [text] as the notation under [ds]: the session to show, and what
/// could not be read.
Reading read(String text, api.DesignSystem? ds) {
  final catalog = ds?.catalogOver(api.standardCatalog) ?? api.standardCatalog;
  final options = ds == null ? const NotationOptions() : NotationOptions.fromDesignSystem(ds);
  final r = api.Catalog.run(catalog, () => parseNotation(text, catalog: catalog, options: options));
  final session = UiSession(
    document: api.LayoutDocument.fromJson(r.document, catalog: catalog),
    designSystem: ds,
    holdEmptyContainers: false,
  );
  return Reading(session, r.issues, r.document, text.length);
}

class Playground extends StatefulWidget {
  const Playground({super.key, required this.loadAsset});
  final Future<String> Function(String key) loadAsset;

  @override
  State<Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<Playground> {
  final _text = TextEditingController();
  final _systems = <String, api.DesignSystem>{};
  final _log = <String>[];
  String _system = designSystems.first;
  String _sample = samples.first;
  Reading? _reading;
  StreamSubscription<Object?>? _events;
  Timer? _debounce;
  String _view = 'preview';
  String _width = '420';

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    // ?sample=approval_card&system=harbor opens on that sample and look.
    final q = Uri.base.queryParameters;
    if (samples.contains(q['sample'])) _sample = q['sample']!;
    if (designSystems.contains(q['system'])) _system = q['system']!;
    for (final id in designSystems) {
      _systems[id] = api.DesignSystem.fromJson(jsonDecode(await widget.loadAsset('assets/design_systems/$id.json')));
    }
    await _pick(_sample);
  }

  Future<void> _pick(String sample) async {
    _sample = sample;
    _text.text = await widget.loadAsset('assets/samples/$sample.txt');
    _render();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _render);
  }

  void _render() {
    _debounce?.cancel();
    if (!mounted || _systems.isEmpty) return;
    final Reading next;
    try {
      next = read(_text.text, _systems[_system]);
    } catch (e) {
      // A document the model cannot hold: keep what is shown, say why.
      setState(() => _log.insert(0, 'Could not be shown: $e'));
      return;
    }
    _events?.cancel();
    _reading?.session.dispose();
    _events = next.session.events.listen((e) {
      if (!mounted) return;
      setState(() {
        _log.insert(0, '${e.toModelMessage()}');
        if (_log.length > 20) _log.removeLast();
      });
    });
    setState(() => _reading = next);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _events?.cancel();
    _reading?.session.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = SoftSaaSTheme.brightnessOf(context);
    final r = _reading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(b, r),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SoftSaaSSplitView(
              axis: box.maxWidth < 760 ? Axis.vertical : Axis.horizontal,
              panes: [
                SoftSaaSSplitPane(minSize: 240, child: _editor(b)),
                SoftSaaSSplitPane(minSize: 280, child: _output(b, r)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The page's bar: its title, the sample, and what the text became.
  Widget _header(Brightness b, Reading? r) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: SoftSaaSTokens.pageGutter),
    decoration: BoxDecoration(
      color: SoftSaaSTokens.primaryBackground(b),
      border: Border(bottom: BorderSide(color: SoftSaaSTokens.primaryBorder(b))),
    ),
    child: Row(
      children: [
        Text('Playground', style: SoftSaaSTypography.sectionTitle(b)),
        const SizedBox(width: 12),
        SoftSaaSDropdown(
          key: const Key('sample'),
          width: 190,
          value: _sample,
          options: [for (final s in samples) SelectOption(value: s, label: _title(s))],
          onChanged: _pick,
        ),
        const SizedBox(width: 12),
        SoftSaaSSegmentedControl<String>(
          key: const Key('system'),
          size: SegmentedControlSize.compact,
          options: [for (final s in designSystems) SegmentedControlOption(value: s, label: _systems[s]?.name ?? s)],
          value: _system,
          onChanged: (s) {
            _system = s;
            _render();
          },
        ),
        const SizedBox(width: 8),
        SoftSaaSSegmentedControl<String>(
          size: SegmentedControlSize.compact,
          options: const [
            SegmentedControlOption(value: '320', label: '320'),
            SegmentedControlOption(value: '420', label: '420'),
            SegmentedControlOption(value: '720', label: '720'),
          ],
          value: _width,
          onChanged: (w) => setState(() => _width = w),
        ),
        const Spacer(),
        if (r != null)
          Flexible(
            child: Text(
              '${r.nodes} nodes · ${r.notationChars} characters written · ${r.jsonChars} as a document',
              key: const Key('stats'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SoftSaaSTypography.caption(b),
            ),
          ),
      ],
    ),
  );

  static String _title(String id) => id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1).replaceAll('_', ' ')}';

  Widget _pane(Brightness b, {required Widget bar, required Widget child, Color? color}) => ColoredBox(
    color: color ?? SoftSaaSTokens.primaryBackground(b),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        Expanded(child: child),
      ],
    ),
  );

  Widget _editor(Brightness b) => _pane(
    b,
    bar: const SoftSaaSPaneToolbar(title: 'Notation'),
    child: SingleChildScrollView(
      child: SoftSaaSCodeField(
        key: const Key('editor'),
        controller: _text,
        lineNumbers: true,
        minLines: 30,
        maxLines: null,
        fontSize: 12.5,
        fillColor: SoftSaaSTokens.primaryBackground(b),
      ),
    ),
  );

  Widget _output(Brightness b, Reading? r) {
    if (r == null) {
      return _pane(
        b,
        bar: const SoftSaaSPaneToolbar(title: 'Preview', loading: true),
        child: const Center(child: SoftSaaSSpinner()),
      );
    }
    return SoftSaaSSplitView(
      axis: Axis.vertical,
      panes: [
        SoftSaaSSplitPane(
          minSize: 160,
          child: _pane(
            b,
            color: SoftSaaSTokens.secondaryBackground(b),
            bar: SoftSaaSPaneToolbar(
              title: _view == 'preview' ? 'Preview' : 'Document',
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SoftSaaSSegmentedControl<String>(
                    key: const Key('view'),
                    size: SegmentedControlSize.xs,
                    options: const [
                      SegmentedControlOption(value: 'preview', label: 'Preview'),
                      SegmentedControlOption(value: 'document', label: 'Document'),
                    ],
                    value: _view,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                ],
              ),
            ),
            child: _view == 'document'
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(SoftSaaSTokens.cardPadding),
                    child: SoftSaaSSelectableText(r.json, style: SoftSaaSTypography.mono(b)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(SoftSaaSTokens.pageGutter),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: double.parse(_width)),
                        child: CodelesslyView(key: ObjectKey(r.session), session: r.session),
                      ),
                    ),
                  ),
          ),
        ),
        SoftSaaSSplitPane(
          size: 150,
          minSize: 64,
          child: _pane(
            b,
            bar: SoftSaaSPaneToolbar(
              title: 'Problems',
              titleMeta: SoftSaaSBadge(
                key: const Key('issues'),
                label: r.issues.isEmpty ? 'Every line was read' : '${r.issues.length} not read',
                variant: r.issues.isEmpty ? SoftSaaSBadgeVariant.success : SoftSaaSBadgeVariant.error,
                size: SoftSaaSBadgeSize.small,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(SoftSaaSTokens.cardPadding),
              children: [
                for (final i in r.issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('$i', style: SoftSaaSTypography.bodySecondary(b).copyWith(color: SoftSaaSTokens.errorColor(b))),
                  ),
                for (final l in _log)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(l, style: SoftSaaSTypography.caption(b)),
                  ),
                if (r.issues.isEmpty && _log.isEmpty)
                  Text('What the UI tells the app (emit, toast) is listed here.', style: SoftSaaSTypography.caption(b)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
