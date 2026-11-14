// A playground for the compact notation: type it on the left, see it
// rendered on the right as you type, under any of the bundled design
// systems. Below the preview: what the parser could not read (with its
// line), what the UI told the app (emit, toast), and the document the
// notation expands to.
//
//   flutter run -d chrome        (or any device)
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart' show CodelesslyView, UiSession;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  Widget build(BuildContext context) => MaterialApp(
        title: 'Codelessly playground',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2563EB), useMaterial3: true),
        home: Playground(loadAsset: loadAsset ?? rootBundle.loadString),
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
  bool _showJson = false;
  double _width = 420;

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
    final r = _reading;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(children: [
          _toolbar(r),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final editor = _editor();
              final preview = _preview(r);
              return box.maxWidth < 760
                  ? Column(children: [Expanded(child: editor), const Divider(height: 1), Expanded(child: preview)])
                  : Row(children: [Expanded(child: editor), const VerticalDivider(width: 1), Expanded(child: preview)]);
            }),
          ),
        ]),
      ),
    );
  }

  Widget _toolbar(Reading? r) => Material(
        color: Colors.white,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Playground', style: TextStyle(fontWeight: FontWeight.w600)),
            DropdownButton<String>(
              key: const Key('sample'),
              value: _sample,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [for (final s in samples) DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))],
              onChanged: (s) => s == null ? null : _pick(s),
            ),
            SegmentedButton<String>(
              key: const Key('system'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [for (final s in designSystems) ButtonSegment(value: s, label: Text(_systems[s]?.name ?? s))],
              selected: {_system},
              onSelectionChanged: (s) {
                _system = s.first;
                _render();
              },
            ),
            SegmentedButton<double>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 320, label: Text('320')),
                ButtonSegment(value: 420, label: Text('420')),
                ButtonSegment(value: 720, label: Text('720')),
              ],
              selected: {_width},
              onSelectionChanged: (s) => setState(() => _width = s.first),
            ),
            if (r != null)
              Text(
                '${r.nodes} nodes · ${r.notationChars} characters written · ${r.jsonChars} as a document',
                key: const Key('stats'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
          ]),
        ),
      );

  Widget _editor() => ColoredBox(
        color: Colors.white,
        child: TextField(
          key: const Key('editor'),
          controller: _text,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
        ),
      );

  Widget _preview(Reading? r) {
    if (r == null) return const Center(child: CircularProgressIndicator());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: _showJson
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(r.json, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _width),
                    child: CodelesslyView(key: ObjectKey(r.session), session: r.session),
                  ),
                ),
              ),
      ),
      const Divider(height: 1),
      ColoredBox(
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(8), children: [
            Row(children: [
              Text(
                r.issues.isEmpty ? 'Every line was read.' : '${r.issues.length} not read:',
                key: const Key('issues'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r.issues.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
              ),
              const Spacer(),
              TextButton(
                key: const Key('json'),
                onPressed: () => setState(() => _showJson = !_showJson),
                child: Text(_showJson ? 'Show preview' : 'Show document'),
              ),
            ]),
            for (final i in r.issues) Text('$i', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            for (final l in _log) Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ]),
        ),
      ),
    ]);
  }
}
