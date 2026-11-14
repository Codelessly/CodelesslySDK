// The notation playground: write UI in the compact notation
// (package:codelessly_api/notation.dart) and see it render as you type.
//
// It is laid out as a full-screen workspace view of CodelesslyEditor (its
// Data, APIs and Fonts views): a 44 px header, then docked panes split by
// hairlines, then a 24 px status bar. Everything in the frame is
// soft_saas_ui; only the preview's content is drawn by the SDK, in the
// chosen design system. README.md lists the Editor conventions followed and
// where each comes from.
//
// [NotationPlayground] fills the box it is given and draws no app chrome of
// its own, so the Editor can show it as one of its workspace pages:
//
//   NotationPlayground(onClose: closePage)
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart' show ActionRun, CodelesslyView, UiEvent, UiSession;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

import 'playground_samples.dart';

export 'playground_samples.dart';

/// Reads an asset by its key.
typedef PlaygroundAssetLoader = Future<String> Function(String key);

/// What one reading of the editor's text gave: the session to show, the
/// lines that could not be read, and the document the text expands to.
class PlaygroundReading {
  PlaygroundReading._(this.session, this.issues, this.document, this.text);

  /// Reads [text] as the notation under [designSystem].
  ///
  /// Throws when the document the text expands to cannot be held by the
  /// model (the caller keeps what it was showing).
  factory PlaygroundReading.read(String text, api.DesignSystem designSystem) {
    final api.Catalog catalog = designSystem.catalogOver(api.standardCatalog);
    final NotationOptions options = NotationOptions.fromDesignSystem(designSystem);
    final NotationResult result = api.Catalog.run(
      catalog,
      () => parseNotation(text, catalog: catalog, options: options),
    );
    final UiSession session = UiSession(
      document: api.LayoutDocument.fromJson(result.document, catalog: catalog),
      designSystem: designSystem,
      holdEmptyContainers: false,
    );
    return PlaygroundReading._(session, result.issues, result.document, text);
  }

  final UiSession session;
  final List<NotationIssue> issues;
  final Map<String, Object?> document;

  /// The text that was read.
  final String text;

  int get nodes => (document['nodes'] as Map<Object?, Object?>?)?.length ?? 0;

  /// The document as it is shown, indented.
  late final String json = const JsonEncoder.withIndent('  ').convert(document);

  /// The characters of the document as it is sent (no white space).
  late final int documentCharacters = jsonEncode(document).length;
}

/// Something the previewed UI told its host.
class PlaygroundEvent {
  const PlaygroundEvent({required this.kind, required this.name, required this.detail, required this.time, this.message});

  /// `emit` or `toast`.
  final String kind;

  /// The event's name, or the toast's text.
  final String name;

  /// The event's value, or the toast's second line.
  final String detail;
  final DateTime time;

  /// What a model would read about it.
  final String? message;
}

/// The playground. Fills its box.
class NotationPlayground extends StatefulWidget {
  const NotationPlayground({
    super.key,
    this.loadAsset,
    this.initialSample,
    this.initialSystem,
    this.actions = const <Widget>[],
    this.onClose,
    this.showStatusBar = true,
    this.debounce = const Duration(milliseconds: 250),
  });

  /// Reads the bundled samples and design systems (the app's bundle by
  /// default; a test gives its own).
  final PlaygroundAssetLoader? loadAsset;

  /// The id of the sample to open on (`approval_card`). Unknown or null:
  /// the first one.
  final String? initialSample;

  /// The id of the design system to open on (`ssui`, `paper`, `harbor`).
  final String? initialSystem;

  /// Controls at the end of the header, before the close button (the
  /// stand-alone app puts its theme toggle here).
  final List<Widget> actions;

  /// Shows the header's close button, as on the Editor's workspace pages.
  final VoidCallback? onClose;

  /// Whether the 24 px status bar (problems, counts) is drawn. A host with a
  /// status bar of its own can turn it off.
  final bool showStatusBar;

  /// How long typing must stop before the preview redraws.
  final Duration debounce;

  /// Below this width the panes stack (the Editor's API builder does the
  /// same at the same width).
  static const double kStackBelow = 760;

  /// Below this width the samples pane leaves the row and opens over the
  /// page instead.
  static const double kDockSamplesFrom = 1100;

  @override
  State<NotationPlayground> createState() => NotationPlaygroundState();
}

class NotationPlaygroundState extends State<NotationPlayground> {
  static const int _kMaxEvents = 100;

  /// The room between the preview's frame and the UI in it.
  static const double _kFramePadding = 16;

  final TextEditingController _text = TextEditingController();
  final TextEditingController _documentText = TextEditingController();
  final FocusNode _editorFocus = FocusNode(debugLabel: 'NotationEditor');
  final GlobalKey _editorKey = GlobalKey(debugLabel: 'NotationEditor');
  final GlobalKey _previewKey = GlobalKey(debugLabel: 'NotationPreview');
  final SoftSaaSTreeController _tree = SoftSaaSTreeController(
    expanded: <String>[for (final PlaygroundSampleGroup group in playgroundSampleGroups) _groupId(group)],
  );
  final SoftSaaSSplitViewController _outerSplit = SoftSaaSSplitViewController();
  final SoftSaaSSplitViewController _workSplit = SoftSaaSSplitViewController();
  final SoftSaaSSplitViewController _sideSplit = SoftSaaSSplitViewController();
  final SoftSaaSSplitViewController _stackSplit = SoftSaaSSplitViewController();

  final Map<String, api.DesignSystem> _systems = <String, api.DesignSystem>{};
  final List<PlaygroundEvent> _events = <PlaygroundEvent>[];

  late PlaygroundSample _sample = playgroundSamples.firstWhere(
    (PlaygroundSample sample) => sample.id == widget.initialSample,
    orElse: () => playgroundSamples.first,
  );
  late PlaygroundDesignSystem _system = playgroundDesignSystems.firstWhere(
    (PlaygroundDesignSystem system) => system.id == widget.initialSystem,
    orElse: () => playgroundDesignSystems.first,
  );

  /// The sample's text as loaded, to tell whether it was edited.
  String _sampleText = '';
  String? _loadError;
  bool _loaded = false;

  PlaygroundReading? _reading;

  /// Why the text as it is now cannot be shown (the last good reading stays).
  String? _failure;
  StreamSubscription<UiEvent>? _subscription;
  Timer? _debounce;
  int _picks = 0;

  int _width = playgroundWidths[1];
  int _drawerTab = 0;
  String _query = '';

  /// The user's choice for the samples pane; null follows the width.
  bool? _samplesOpen;

  PlaygroundAssetLoader get _loadAsset => widget.loadAsset ?? rootBundle.loadString;

  static String _groupId(PlaygroundSampleGroup group) => 'group/${group.id}';

  /// The editor's text, for a host or a test.
  TextEditingController get text => _text;

  /// The current reading: what is shown.
  PlaygroundReading? get reading => _reading;

  @override
  void initState() {
    super.initState();
    _text.addListener(_textChanged);
    _tree.setSelection(<String>{_sample.id});
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    _reading?.session.dispose();
    _text.dispose();
    _documentText.dispose();
    _editorFocus.dispose();
    _tree.dispose();
    _outerSplit.dispose();
    _workSplit.dispose();
    _sideSplit.dispose();
    _stackSplit.dispose();
    super.dispose();
  }

  // ─── Loading ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _loaded = false;
    });
    try {
      for (final PlaygroundDesignSystem system in playgroundDesignSystems) {
        final Object? json = jsonDecode(await _loadAsset(system.asset));
        _systems[system.id] = api.DesignSystem.fromJson((json! as Map<Object?, Object?>).cast<String, Object?>());
      }
      final String sample = await _loadAsset(_sample.asset);
      if (!mounted) return;
      _loaded = true;
      _open(_sample, sample);
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = '$error');
    }
  }

  /// Loads [sample] into the editor, replacing what is there.
  Future<void> _pick(PlaygroundSample sample) async {
    final int pick = ++_picks;
    final String text;
    try {
      text = await _loadAsset(sample.asset);
    } on Object catch (error) {
      if (mounted) SoftSaaSToaster.maybeOf(context)?.error('Could not load ${sample.title}', description: '$error');
      return;
    }
    if (!mounted || pick != _picks) return;
    _open(sample, text);
  }

  void _open(PlaygroundSample sample, String text) {
    _sample = sample;
    _sampleText = text;
    _tree.setSelection(<String>{sample.id});
    _text.value = TextEditingValue(text: text, selection: const TextSelection.collapsed(offset: 0));
    // On a narrow window the samples pane covers the page: picking closes it.
    if (_samplesOpen ?? false) {
      final double? width = context.size?.width;
      if (width != null && width < NotationPlayground.kDockSamplesFrom) _samplesOpen = null;
    }
    _render();
  }

  // ─── Reading ────────────────────────────────────────────────────────────

  void _textChanged() {
    // The controller also notifies when only the cursor moved.
    if (_text.text == (_failure == null ? _reading?.text : null) && !(_debounce?.isActive ?? false)) return;
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, _render);
    // The header's "edited" mark follows the text at once.
    if (mounted) setState(() {});
  }

  /// Reads the text again and shows it in a new session (the UI's state
  /// starts over).
  void _render() {
    _debounce?.cancel();
    final api.DesignSystem? designSystem = _systems[_system.id];
    if (!mounted || !_loaded || designSystem == null) return;
    final PlaygroundReading next;
    try {
      next = PlaygroundReading.read(_text.text, designSystem);
    } on Object catch (error) {
      setState(() => _failure = '$error');
      return;
    }
    final PlaygroundReading? previous = _reading;
    unawaited(_subscription?.cancel());
    _subscription = next.session.events.listen(_onUiEvent);
    _documentText.text = next.json;
    setState(() {
      _reading = next;
      _failure = null;
    });
    // The view of the previous session goes with this frame.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.session.dispose());
    }
  }

  void _setSystem(PlaygroundDesignSystem system) {
    if (system.id == _system.id) return;
    _system = system;
    _render();
  }

  // ─── Events ─────────────────────────────────────────────────────────────

  void _log(PlaygroundEvent event) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > _kMaxEvents) _events.removeLast();
    });
  }

  void _onUiEvent(UiEvent event) {
    String detail = '';
    if (event.value != null) {
      try {
        detail = jsonEncode(event.value);
      } on Object {
        detail = '${event.value}';
      }
    }
    _log(PlaygroundEvent(kind: 'emit', name: event.event, detail: detail, time: DateTime.now(), message: event.toModelMessage()));
  }

  /// A `toast` of the previewed UI: the host shows it, as it would in an app.
  FutureOr<void> _onToast(api.ActionDef action, ActionRun run) {
    if (action is! api.ShowToastAction) return null;
    final String title = run.text(action.title);
    final String message = run.text(action.message);
    final String first = title.isEmpty ? message : title;
    final String second = title.isEmpty ? '' : message;
    _log(PlaygroundEvent(kind: 'toast', name: first, detail: second, time: DateTime.now()));
    if (!mounted) return null;
    SoftSaaSToaster.maybeOf(context)?.show(
      first,
      description: second.isEmpty ? null : second,
      kind: switch (action.toastStyle) {
        api.ToastStyle.success => SoftSaaSToastKind.success,
        api.ToastStyle.error => SoftSaaSToastKind.error,
        api.ToastStyle.info => SoftSaaSToastKind.info,
        _ => SoftSaaSToastKind.neutral,
      },
    );
    return null;
  }

  // ─── Commands ───────────────────────────────────────────────────────────

  void _copy(String text, String what) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    SoftSaaSToaster.maybeOf(context)?.success('$what copied');
  }

  void _restoreSample() {
    _text.value = TextEditingValue(text: _sampleText, selection: const TextSelection.collapsed(offset: 0));
    _render();
  }

  /// Puts the cursor where [issue] is and brings that line into view.
  void goToIssue(NotationIssue issue) {
    final String text = _text.text;
    int start = 0;
    for (int line = 1; line < issue.line; line++) {
      final int end = text.indexOf('\n', start);
      if (end < 0) break;
      start = end + 1;
    }
    int end = text.indexOf('\n', start);
    if (end < 0) end = text.length;
    final int offset = math.min(start + math.max(issue.column - 1, 0), end);
    // From the column to the end of the line, so the place is easy to see.
    _text.selection = TextSelection(baseOffset: offset, extentOffset: end);
    _editorFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? field = _editorKey.currentContext;
      if (field == null) return;
      EditableTextState? editable;
      void visit(Element element) {
        if (editable != null) return;
        if (element is StatefulElement && element.state is EditableTextState) {
          editable = element.state as EditableTextState;
          return;
        }
        element.visitChildren(visit);
      }

      field.visitChildElements(visit);
      editable?.bringIntoView(TextPosition(offset: offset));
    });
  }

  void _onTreeSelection(Set<String> ids) {
    final String? id = ids.length == 1 ? ids.first : null;
    final PlaygroundSample? sample = playgroundSamples.where((PlaygroundSample s) => s.id == id).firstOrNull;
    if (sample == null) {
      // A folder: it opens or closes, and the open sample stays selected.
      if (id != null) _tree.toggle(id);
      _tree.setSelection(<String>{_sample.id});
      return;
    }
    if (sample.id != _sample.id) unawaited(_pick(sample));
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = SoftSaaSTheme.brightnessOf(context);
    return DefaultTextStyle.merge(
      style: SoftSaaSTypography.body(brightness),
      child: ColoredBox(
        color: SoftSaaSTokens.primaryBackground(brightness),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PlaygroundHeader(
              system: _system,
              onSystemChanged: _loaded ? _setSystem : null,
              actions: widget.actions,
              onClose: widget.onClose,
            ),
            Expanded(child: _body(brightness)),
            if (widget.showStatusBar) _statusBar(brightness),
          ],
        ),
      ),
    );
  }

  Widget _body(Brightness brightness) {
    if (_loadError != null) {
      return _PaneMessage(
        key: const ValueKey<String>('playground-load-error'),
        icon: LucideIcons.circle_x,
        title: 'The playground could not load',
        description: _loadError,
        action: SoftSaaSButton(
          variant: SoftSaaSButtonVariant.outline,
          icon: LucideIcons.rotate_ccw,
          onPressed: () => unawaited(_load()),
          child: const Text('Try again'),
        ),
      );
    }
    if (!_loaded) {
      return Center(
        key: const ValueKey<String>('playground-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SoftSaaSLoadingSpinner(),
            const SizedBox(height: 12),
            Text('Loading the design systems…', style: SoftSaaSTypography.bodySecondary(brightness)),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < NotationPlayground.kStackBelow;
        final bool canDock = constraints.maxWidth >= NotationPlayground.kDockSamplesFrom;
        final bool samplesOpen = _samplesOpen ?? canDock;
        void toggleSamples() => setState(() => _samplesOpen = !samplesOpen);
        final Widget work = _work(brightness, stacked: stacked, onShowSamples: samplesOpen ? null : toggleSamples);
        if (canDock) {
          if (!samplesOpen) return work;
          return SoftSaaSSplitView(
            key: const ValueKey<String>('playground-split-outer'),
            controller: _outerSplit,
            panes: <SoftSaaSSplitPane>[
              SoftSaaSSplitPane(size: 264, minSize: 208, maxSize: 420, child: _samples(brightness, onClose: toggleSamples)),
              SoftSaaSSplitPane(minSize: 560, child: work),
            ],
          );
        }
        // Not enough room to dock the samples: they open over the page.
        final double drawer = (constraints.maxWidth - 48).clamp(200.0, 320.0);
        return Stack(
          children: <Widget>[
            Positioned.fill(child: work),
            if (samplesOpen) ...<Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: toggleSamples,
                  child: ColoredBox(color: SoftSaaSTokens.scrim(brightness)),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: drawer,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: SoftSaaSTokens.primaryBorder(brightness))),
                  ),
                  child: _samples(brightness, onClose: toggleSamples),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _work(Brightness brightness, {required bool stacked, VoidCallback? onShowSamples}) {
    final Widget editor = _editor(brightness, onShowSamples: onShowSamples);
    final Widget preview = _preview(brightness);
    final Widget drawer = _drawer(brightness);
    if (stacked) {
      return SoftSaaSSplitView(
        key: const ValueKey<String>('playground-split-stack'),
        axis: Axis.vertical,
        controller: _stackSplit,
        panes: <SoftSaaSSplitPane>[
          SoftSaaSSplitPane(flex: 10, minSize: 120, child: editor),
          SoftSaaSSplitPane(flex: 12, minSize: 120, child: preview),
          SoftSaaSSplitPane(size: 188, minSize: 72, child: drawer),
        ],
      );
    }
    return SoftSaaSSplitView(
      key: const ValueKey<String>('playground-split-work'),
      controller: _workSplit,
      panes: <SoftSaaSSplitPane>[
        SoftSaaSSplitPane(flex: 10, minSize: 280, child: editor),
        SoftSaaSSplitPane(
          flex: 12,
          minSize: 320,
          child: SoftSaaSSplitView(
            key: const ValueKey<String>('playground-split-side'),
            axis: Axis.vertical,
            controller: _sideSplit,
            panes: <SoftSaaSSplitPane>[
              SoftSaaSSplitPane(minSize: 160, child: preview),
              SoftSaaSSplitPane(size: 220, minSize: 108, child: drawer),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Samples ────────────────────────────────────────────────────────────

  Widget _samples(Brightness brightness, {required VoidCallback onClose}) {
    _tree.filter = _query;
    return ColoredBox(
      color: SoftSaaSTokens.secondaryBackground(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PaneHeader(
            title: 'Samples',
            meta: '${playgroundSamples.length}',
            actions: <Widget>[
              SoftSaaSEditorIconAction(
                key: const ValueKey<String>('playground-samples-close'),
                icon: LucideIcons.panel_left_close,
                tooltip: 'Hide samples',
                onPressed: onClose,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: SoftSaaSSearchBar(
              key: const ValueKey<String>('playground-samples-search'),
              placeholder: 'Search samples',
              debounce: const Duration(milliseconds: 100),
              onSearchChanged: (String value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: SoftSaaSTreeView<PlaygroundSample?>(
              key: const ValueKey<String>('playground-samples'),
              controller: _tree,
              showGuides: false,
              onSelectionChanged: _onTreeSelection,
              roots: <SoftSaaSTreeNode<PlaygroundSample?>>[
                for (final PlaygroundSampleGroup group in playgroundSampleGroups)
                  SoftSaaSTreeNode<PlaygroundSample?>(
                    id: _groupId(group),
                    label: group.title,
                    data: null,
                    icon: _tree.isExpanded(_groupId(group)) ? LucideIcons.folder_open : LucideIcons.folder,
                    canHaveChildren: true,
                    renamable: false,
                    draggable: false,
                    children: <SoftSaaSTreeNode<PlaygroundSample?>>[
                      for (final PlaygroundSample sample in group.samples)
                        SoftSaaSTreeNode<PlaygroundSample?>(
                          id: sample.id,
                          label: sample.title,
                          data: sample,
                          icon: LucideIcons.file_text,
                          canHaveChildren: false,
                          renamable: false,
                          draggable: false,
                        ),
                    ],
                  ),
              ],
              trailingBuilder: (BuildContext context, SoftSaaSTreeNode<PlaygroundSample?> node, bool hovered, bool selected) {
                if (node.data != null) return null;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('${node.children.length}', style: SoftSaaSTypography.caption(brightness)),
                );
              },
              emptyBuilder: (BuildContext context) => _PaneMessage(
                icon: LucideIcons.search,
                title: 'No matches',
                description: 'No sample is named like "${_query.trim()}".',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Editor ─────────────────────────────────────────────────────────────

  Widget _editor(Brightness brightness, {VoidCallback? onShowSamples}) {
    final bool edited = _text.text != _sampleText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PaneHeader(
          title: 'Notation',
          meta: edited ? '${_sample.title} · edited' : _sample.title,
          leading: onShowSamples == null
              ? null
              : SoftSaaSEditorIconAction(
                  key: const ValueKey<String>('playground-samples-open'),
                  icon: LucideIcons.panel_left_open,
                  tooltip: 'Show samples',
                  onPressed: onShowSamples,
                ),
          actions: <Widget>[
            SoftSaaSEditorIconAction(
              key: const ValueKey<String>('playground-restore'),
              icon: LucideIcons.rotate_ccw,
              tooltip: 'Restore the sample',
              onPressed: edited ? _restoreSample : null,
            ),
            SoftSaaSEditorIconAction(
              key: const ValueKey<String>('playground-copy-notation'),
              icon: LucideIcons.copy,
              tooltip: 'Copy the notation',
              onPressed: () => _copy(_text.text, 'Notation'),
            ),
          ],
        ),
        Expanded(
          child: _FilledCodeField(
            fieldKey: _editorKey,
            controller: _text,
            focusNode: _editorFocus,
            hasError: _failure != null,
            placeholder: 'Card gap:12\n  Text.sectionTitle "Hello"\n  Button "Save" -> emit save',
          ),
        ),
      ],
    );
  }

  // ─── Preview ────────────────────────────────────────────────────────────

  Widget _preview(Brightness brightness) {
    final PlaygroundReading? reading = _reading;
    final Widget canvas;
    if (reading == null) {
      canvas = const SizedBox.shrink();
    } else if (reading.nodes == 0) {
      canvas = _PaneMessage(
        key: const ValueKey<String>('playground-preview-empty'),
        icon: LucideIcons.square_dashed,
        title: reading.text.trim().isEmpty ? 'Nothing to preview yet' : 'Nothing could be read',
        description: reading.text.trim().isEmpty
            ? 'Write a node on the first line, such as Text "Hello", or open a sample. Children go two spaces under their parent.'
            : 'No line of the text is a node. Problems lists what the parser made of each one.',
        footer: reading.text.trim().isEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Indent', style: SoftSaaSTypography.caption(brightness)),
                  const SizedBox(width: 6),
                  const SoftSaaSKbd(keys: <String>['Tab']),
                ],
              )
            : null,
      );
    } else {
      canvas = SoftSaaSCanvasShell(
        key: const ValueKey<String>('playground-canvas'),
        child: Align(
          alignment: Alignment.topCenter,
          // The frame the UI is drawn in, as a screen on the Editor's board.
          // It is light in both themes: the notation's own colors (a
          // Card's fill, a Box's) are written for a light surface.
          child: Container(
            key: const ValueKey<String>('playground-frame'),
            width: _width + _kFramePadding * 2,
            padding: const EdgeInsets.all(_kFramePadding),
            decoration: BoxDecoration(
              color: SoftSaaSTokens.primaryBackground(Brightness.light),
              border: Border.all(color: SoftSaaSTokens.primaryBorder(brightness)),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(platformBrightness: Brightness.light),
              child: KeyedSubtree(
                key: _previewKey,
                child: CodelesslyView(
                  key: ObjectKey(reading.session),
                  session: reading.session,
                  handlers: <String, FutureOr<void> Function(api.ActionDef, ActionRun)>{
                    api.ShowToastAction.typeName: _onToast,
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: SoftSaaSTokens.secondaryBackground(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ColoredBox(
            color: SoftSaaSTokens.primaryBackground(brightness),
            child: _PaneHeader(
              title: 'Preview',
              meta: '${_system.name} · $_width px',
              actions: <Widget>[
                SoftSaaSEditorIconAction(
                  key: const ValueKey<String>('playground-restart'),
                  icon: LucideIcons.refresh_cw,
                  tooltip: 'Restart the preview',
                  onPressed: reading == null ? null : _render,
                ),
                const SizedBox(width: 6),
                SoftSaaSSegmentedControl<int>(
                  key: const ValueKey<String>('playground-width'),
                  controlSize: SoftSaaSControlSize.xs,
                  value: _width,
                  onChanged: (int width) => setState(() => _width = width),
                  options: <SegmentedControlOption<int>>[
                    for (final int width in playgroundWidths) SegmentedControlOption<int>(value: width, label: '$width'),
                  ],
                ),
              ],
            ),
          ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SoftSaaSBanner(
                key: const ValueKey<String>('playground-failure'),
                type: SoftSaaSBannerType.error,
                title: 'This text cannot be shown',
                message: 'The preview is the last text that could. $_failure',
              ),
            ),
          Expanded(child: canvas),
        ],
      ),
    );
  }

  // ─── Problems, events, document ─────────────────────────────────────────

  Widget _drawer(Brightness brightness) {
    final PlaygroundReading? reading = _reading;
    final List<NotationIssue> issues = reading?.issues ?? const <NotationIssue>[];
    return SoftSaaSTabbedPanel(
      key: const ValueKey<String>('playground-drawer'),
      selectedIndex: _drawerTab,
      onChanged: (int tab) => setState(() => _drawerTab = tab),
      // The lists follow the reading: nothing to keep between visits.
      keepAlive: false,
      trailing: <Widget>[
        if (_drawerTab == 1)
          SoftSaaSEditorIconAction(
            key: const ValueKey<String>('playground-events-clear'),
            icon: LucideIcons.list_x,
            tooltip: 'Clear events',
            onPressed: _events.isEmpty ? null : () => setState(_events.clear),
          ),
        if (_drawerTab == 2)
          SoftSaaSEditorIconAction(
            key: const ValueKey<String>('playground-copy-document'),
            icon: LucideIcons.copy,
            tooltip: 'Copy the document',
            onPressed: reading == null ? null : () => _copy(reading.json, 'Document'),
          ),
      ],
      tabs: <SoftSaaSPanelTab>[
        SoftSaaSPanelTab(
          key: const ValueKey<String>('playground-tab-problems'),
          label: 'Problems',
          badge: issues.isEmpty ? null : issues.length,
          builder: (BuildContext context) => issues.isEmpty
              ? const _PaneMessage(
                  key: ValueKey<String>('playground-no-problems'),
                  icon: LucideIcons.circle_check,
                  title: 'No problems',
                  description: 'Every line was read.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: issues.length,
                  itemExtent: SoftSaaSEditorMetrics.row,
                  itemBuilder: (BuildContext context, int index) => _ProblemRow(
                    key: ValueKey<String>('playground-problem-$index'),
                    issue: issues[index],
                    onPressed: () => goToIssue(issues[index]),
                  ),
                ),
        ),
        SoftSaaSPanelTab(
          key: const ValueKey<String>('playground-tab-events'),
          label: 'Events',
          badge: _events.isEmpty ? null : _events.length,
          builder: (BuildContext context) => _events.isEmpty
              ? const _PaneMessage(
                  key: ValueKey<String>('playground-no-events'),
                  icon: LucideIcons.radio,
                  title: 'No events yet',
                  description: 'What the previewed UI tells its host with emit or toast is listed here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _events.length,
                  itemExtent: SoftSaaSEditorMetrics.row,
                  itemBuilder: (BuildContext context, int index) => _EventRow(event: _events[index]),
                ),
        ),
        SoftSaaSPanelTab(
          key: const ValueKey<String>('playground-tab-document'),
          label: 'Document',
          builder: (BuildContext context) => _FilledCodeField(
            fieldKey: const ValueKey<String>('playground-document'),
            controller: _documentText,
            readOnly: true,
          ),
        ),
      ],
    );
  }

  // ─── Status bar ─────────────────────────────────────────────────────────

  Widget _statusBar(Brightness brightness) {
    final PlaygroundReading? reading = _reading;
    final int problems = reading?.issues.length ?? 0;
    final bool failed = _failure != null;
    return Container(
      height: SoftSaaSEditorMetrics.statusBar,
      decoration: BoxDecoration(
        color: SoftSaaSTokens.secondaryBackground(brightness),
        border: Border(top: BorderSide(color: SoftSaaSTokens.primaryBorder(brightness))),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= NotationPlayground.kStackBelow;
          return SoftSaaSStatusBar(
            leading: <Widget>[
              if (reading != null)
                SoftSaaSStatusItem(
                  key: const ValueKey<String>('playground-status-problems'),
                  icon: failed || problems > 0 ? LucideIcons.circle_x : LucideIcons.circle_check,
                  label: failed
                      ? 'Cannot be shown'
                      : problems == 0
                      ? 'No problems'
                      : '$problems ${problems == 1 ? 'problem' : 'problems'}',
                  color: failed || problems > 0 ? SoftSaaSTokens.errorColor(brightness) : null,
                  tooltip: 'Show problems',
                  onPressed: () => setState(() => _drawerTab = 0),
                ),
            ],
            trailing: <Widget>[
              if (reading != null) ...<Widget>[
                if (constraints.maxWidth >= 420)
                  SoftSaaSStatusItem(
                    key: const ValueKey<String>('playground-status-nodes'),
                    label: '${_count(reading.nodes)} ${reading.nodes == 1 ? 'node' : 'nodes'}',
                    tooltip: 'Nodes in the document',
                  ),
                SoftSaaSStatusItem(
                  key: const ValueKey<String>('playground-status-written'),
                  label: '${_count(reading.text.length)} ${wide ? 'characters written' : 'written'}',
                  tooltip: 'Characters of notation written',
                ),
                SoftSaaSStatusItem(
                  key: const ValueKey<String>('playground-status-document'),
                  label: '${_count(reading.documentCharacters)} ${wide ? 'as a document' : 'as JSON'}',
                  tooltip: 'Characters of the JSON document the notation expands to',
                  onPressed: () => setState(() => _drawerTab = 2),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// [value] with thousands separators.
  static String _count(int value) {
    final String digits = '$value';
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// The page's 44 px header: a tinted icon, the title and what the page is,
/// then the design system switch, the host's actions and a close button
/// (the anatomy of the Editor's WorkspaceFullscreenHeader).
class _PlaygroundHeader extends StatelessWidget {
  const _PlaygroundHeader({required this.system, required this.onSystemChanged, required this.actions, this.onClose});

  final PlaygroundDesignSystem system;

  /// Null while the design systems load.
  final ValueChanged<PlaygroundDesignSystem>? onSystemChanged;
  final List<Widget> actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = SoftSaaSTheme.brightnessOf(context);
    return Container(
      height: SoftSaaSEditorMetrics.topBar,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: SoftSaaSTokens.primaryBorder(brightness))),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool showSubtitle = constraints.maxWidth >= 1000;
          final bool showLabel = constraints.maxWidth >= 760;
          final bool showTitle = constraints.maxWidth >= 560;
          final bool segmented = constraints.maxWidth >= 480;
          return Row(
            children: <Widget>[
              SoftSaaSTooltip(
                content: showTitle ? null : 'Notation playground',
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: SoftSaaSTokens.controlActiveTint(brightness),
                    borderRadius: BorderRadius.circular(SoftSaaSTokens.radiusControl),
                  ),
                  child: Icon(LucideIcons.square_terminal, size: 16, color: SoftSaaSTokens.primaryColor(brightness)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: <Widget>[
                    if (showTitle)
                      Flexible(
                        child: Text(
                          'Notation playground',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoftSaaSTypography.sectionTitle(brightness),
                        ),
                      ),
                    if (showSubtitle) ...<Widget>[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Write UI as text, one node per line, and see it render',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoftSaaSTypography.bodySecondary(brightness),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (showLabel) ...<Widget>[
                Text('Design system', maxLines: 1, style: SoftSaaSTypography.fieldLabel(brightness)),
                const SizedBox(width: 8),
              ],
              if (segmented)
                SoftSaaSSegmentedControl<String>(
                  key: const ValueKey<String>('playground-system'),
                  value: system.id,
                  enabled: onSystemChanged != null,
                  onChanged: (String id) => onSystemChanged?.call(
                    playgroundDesignSystems.firstWhere((PlaygroundDesignSystem s) => s.id == id),
                  ),
                  options: <SegmentedControlOption<String>>[
                    for (final PlaygroundDesignSystem s in playgroundDesignSystems)
                      SegmentedControlOption<String>(value: s.id, label: s.name),
                  ],
                )
              else
                SoftSaaSDropdown(
                  key: const ValueKey<String>('playground-system'),
                  width: 140,
                  value: system.id,
                  enabled: onSystemChanged != null,
                  options: <SelectOption>[
                    for (final PlaygroundDesignSystem s in playgroundDesignSystems) SelectOption(value: s.id, label: s.name),
                  ],
                  onChanged: (String id) => onSystemChanged?.call(
                    playgroundDesignSystems.firstWhere((PlaygroundDesignSystem s) => s.id == id),
                  ),
                ),
              for (final Widget action in actions) ...<Widget>[const SizedBox(width: 8), action],
              if (onClose != null) ...<Widget>[
                const SizedBox(width: 4),
                SoftSaaSIconButton(
                  key: const ValueKey<String>('playground-close'),
                  icon: LucideIcons.x,
                  tooltip: 'Close (Esc)',
                  onPressed: onClose,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A pane's 36 px header: the title and a quiet note after it, then the
/// pane's actions at the right edge.
///
/// [SoftSaaSPanelHeader] with the title in its `leading`, expanded, as the
/// Editor's StudioPanelHeader does: the header's own title slot shares the
/// free space with a spacer, which leaves the actions short of the edge.
class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.title, this.meta, this.leading, this.actions = const <Widget>[]});

  final String title;
  final String? meta;

  /// An action before the title.
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = SoftSaaSTheme.brightnessOf(context);
    return SoftSaaSPanelHeader(
      title: '',
      leading: Expanded(
        flex: 1000,
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[leading!, const SizedBox(width: 6)],
            Text(title, maxLines: 1, style: SoftSaaSTypography.panelTitle(brightness)),
            if (meta != null) ...<Widget>[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SoftSaaSTypography.caption(brightness),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: actions,
    );
  }
}

/// A pane body's centered message: nothing here, nothing found, failed (the
/// Editor's StudioPanelMessage).
class _PaneMessage extends StatelessWidget {
  const _PaneMessage({super.key, required this.icon, required this.title, this.description, this.action, this.footer});

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  /// A line of hints under the message.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SoftSaaSEmptyState(
              icon: icon,
              title: title,
              description: description,
              action: action,
              background: SoftSaaSEmptyBackground.transparent,
              border: SoftSaaSEmptyBorder.none,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              iconSize: 16,
              iconTileSize: 36,
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// A code field that fills its pane inside an 8 px gutter and scrolls
/// within its frame: as many rows as fit.
class _FilledCodeField extends StatelessWidget {
  const _FilledCodeField({
    required this.fieldKey,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.hasError = false,
    this.placeholder,
  });

  static const double _fontSize = 12;
  static const double _lineHeight = _fontSize * 1.5;
  static const double _gutter = 8;

  /// The field's own vertical padding (SoftSaaSCodeField).
  static const double _fieldPadding = 16;

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool hasError;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double room = constraints.maxHeight - _gutter * 2 - _fieldPadding;
        final int rows = math.max(2, (room / _lineHeight).floor());
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(_gutter),
          child: SoftSaaSCodeField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            lineNumbers: true,
            fontSize: _fontSize,
            minLines: rows,
            maxLines: rows,
            readOnly: readOnly,
            hasError: hasError,
            placeholder: placeholder,
          ),
        );
      },
    );
  }
}

/// One line the parser could not read: what is wrong, then where. Selecting
/// it goes to the line.
class _ProblemRow extends StatelessWidget {
  const _ProblemRow({super.key, required this.issue, required this.onPressed});

  final NotationIssue issue;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = SoftSaaSTheme.brightnessOf(context);
    // "No Button.huge. Variants: primary, …": what is wrong, then the help.
    final int split = issue.message.indexOf('. ');
    final String what = split < 0 ? issue.message : issue.message.substring(0, split + 1);
    final String help = split < 0 ? '' : issue.message.substring(split + 2);
    return SoftSaaSTooltip(
      content: issue.message,
      maxWidth: 360,
      child: _ListRow(
        onPressed: onPressed,
        semanticLabel: 'Line ${issue.line}, column ${issue.column}: ${issue.message}',
        children: <Widget>[
          Icon(LucideIcons.circle_x, size: 14, color: SoftSaaSTokens.errorColor(brightness)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: what,
                style: SoftSaaSTypography.inputText(brightness),
                children: <InlineSpan>[
                  if (help.isNotEmpty) TextSpan(text: '  $help', style: SoftSaaSTypography.bodySecondary(brightness)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Ln ${issue.line}, Col ${issue.column}',
            maxLines: 1,
            style: SoftSaaSTypography.caption(brightness),
          ),
        ],
      ),
    );
  }
}

/// One thing the UI told its host: its kind, its name and value, and when.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final PlaygroundEvent event;

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = SoftSaaSTheme.brightnessOf(context);
    final Color color = event.kind == 'emit' ? SoftSaaSTokens.infoColor(brightness) : SoftSaaSTokens.purpleColor(brightness);
    final DateTime time = event.time;
    return SoftSaaSTooltip(
      content: event.message,
      maxWidth: 360,
      child: _ListRow(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(
              event.kind.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(fontSize: 9.5, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: color),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: event.name,
                style: SoftSaaSTypography.inputText(brightness),
                children: <InlineSpan>[
                  if (event.detail.isNotEmpty)
                    TextSpan(text: '  ${event.detail}', style: SoftSaaSTypography.mono(brightness).copyWith(fontSize: 11.5)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}',
            maxLines: 1,
            style: SoftSaaSTypography.caption(brightness),
          ),
        ],
      ),
    );
  }
}

/// A 28 px row of a pane's list: inset 4 px, with the shared hover overlay
/// and focus ring when it can be pressed.
class _ListRow extends StatelessWidget {
  const _ListRow({required this.children, this.onPressed, this.semanticLabel});

  final List<Widget> children;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = SoftSaaSTheme.brightnessOf(context);
    return SoftSaaSPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      isButton: onPressed != null,
      builder: (BuildContext context, SoftSaaSPressableState state) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: state.highlighted ? SoftSaaSTokens.controlHoverOverlay(brightness) : null,
          borderRadius: BorderRadius.circular(SoftSaaSTokens.radiusInner),
          boxShadow: SoftSaaSPressable.focusRing(brightness, state.focused),
        ),
        child: Row(children: children),
      ),
    );
  }
}
