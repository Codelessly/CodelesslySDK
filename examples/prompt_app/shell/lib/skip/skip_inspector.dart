// The storyboard's right panel, laid out as the Editor's inspector: the
// properties (sections of rows built by the dynamic properties panel from
// the one schema) over what the screens told the app.
import 'dart:convert';

import 'package:dynamic_properties_panel/dynamic_properties_panel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

import '../skip_app.dart';
import 'skip_controls.dart';
import 'skip_screen.dart';

/// The Editor's default width for its right panel.
const double kInspectorWidth = 300;

class SkipInspector extends StatelessWidget {
  const SkipInspector({super.key, this.onHide});

  /// Hides the panel (the button at the end of its header).
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final b = SoftSaaSTheme.brightnessOf(context);
    final scope = SkipScope.of(context);
    return ColoredBox(
      color: SoftSaaSTokens.primaryBackground(b),
      child: SoftSaaSSplitView(
        axis: Axis.vertical,
        panes: [
          SoftSaaSSplitPane(
            minSize: 160,
            child: _Properties(controls: scope.controls, onHide: onHide),
          ),
          SoftSaaSSplitPane(size: 224, minSize: 100, child: _Events(app: scope.app)),
        ],
      ),
    );
  }
}

/// A pane's 36 px header. `SoftSaaSPanelHeader` shares its free space
/// between its title and a spacer, so the title goes in `leading`, expanded,
/// and the actions reach the edge (the Editor's `StudioPanelHeader`).
class _Header extends StatelessWidget {
  const _Header({required this.title, this.count, this.actions = const []});

  final String title;
  final int? count;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final b = SoftSaaSTheme.brightnessOf(context);
    return SoftSaaSPanelHeader(
      title: '',
      leading: Expanded(
        flex: 1000,
        child: Row(
          children: [
            Text(title, maxLines: 1, style: SoftSaaSTypography.panelTitle(b)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count', maxLines: 1, style: SoftSaaSTypography.caption(b)),
            ],
          ],
        ),
      ),
      actions: actions,
    );
  }
}

class _Properties extends StatelessWidget {
  const _Properties({required this.controls, this.onHide});

  final SkipControls controls;
  final VoidCallback? onHide;

  Widget _rows(List<String> keys) => DynamicPropertiesPanel(
    key: ValueKey(keys.join(',')),
    controller: controls.controller,
    properties: controls.rows(keys),
    showContainer: false,
    showBreadcrumbs: false,
    rowLayout: DynamicPropertyRowLayout.inline,
    maxInlineDepth: 5,
  );

  @override
  Widget build(BuildContext context) {
    final app = controls.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Properties',
          actions: [
            if (onHide != null)
              SoftSaaSEditorIconAction(
                icon: LucideIcons.panel_right_close,
                tooltip: 'Hide properties',
                onPressed: onHide,
              ),
          ],
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              if (!app.ready) {
                return Center(
                  child: app.failure != null
                      ? PaneMessage(
                          icon: LucideIcons.triangle_alert,
                          title: 'Nothing to control yet',
                          description: 'The app could not be read.',
                          actionLabel: 'Try again',
                          onAction: app.start,
                        )
                      : const SoftSaaSLoadingSpinner(),
                );
              }
              return ListView(
                key: const PageStorageKey('skip-properties'),
                children: [
                  SoftSaaSInspectorSection(
                    key: const ValueKey('section-shown'),
                    title: 'Shown',
                    storageKey: 'skip.shown',
                    children: [_rows(shownKeys)],
                  ),
                  SoftSaaSInspectorSection(
                    key: const ValueKey('section-store'),
                    title: 'Store',
                    storageKey: 'skip.store',
                    children: [_rows(storeKeys)],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Events extends StatelessWidget {
  const _Events({required this.app});

  final SkipApp app;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Events',
          count: app.log.isEmpty ? null : app.log.length,
          actions: [
            SoftSaaSEditorIconAction(
              icon: LucideIcons.eraser,
              tooltip: 'Clear events',
              onPressed: app.log.isEmpty ? null : app.clearLog,
            ),
          ],
        ),
        Expanded(
          child: app.log.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: PaneMessage(
                      icon: LucideIcons.radio,
                      title: 'No events yet',
                      description: 'Tap in the phone. Each action a screen fires is listed here, newest first.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemExtent: SoftSaaSEditorMetrics.row,
                  itemCount: app.log.length,
                  itemBuilder: (context, i) => _EventRow(line: app.log[i]),
                ),
        ),
      ],
    ),
  );
}

/// One thing a screen told the app: whether the app acted on it, its name
/// and value, and when.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.line});

  final LogLine line;

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final b = SoftSaaSTheme.brightnessOf(context);
    final color = line.handled ? SoftSaaSTokens.infoColor(b) : SoftSaaSTokens.tertiaryText(b);
    final value = line.value == null ? '' : jsonEncode(line.value);
    final t = line.time;
    return SoftSaaSTooltip(
      content: line.handled
          ? 'From ${line.screen} (${line.person}). The app acted on it.'
          : 'From the ${line.screen} story (${line.person}). A story only lists what its screen says; Run the app acts on it.',
      maxWidth: 280,
      child: SoftSaaSPressable(
        isButton: false,
        builder: (context, state) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: state.highlighted ? SoftSaaSTokens.controlHoverOverlay(b) : null,
            borderRadius: BorderRadius.circular(SoftSaaSTokens.radiusInner),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  line.handled ? 'EMIT' : 'STORY',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: color,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: line.event,
                    style: SoftSaaSTypography.inputText(b),
                    children: [
                      if (value.isNotEmpty)
                        TextSpan(text: '  $value', style: SoftSaaSTypography.mono(b).copyWith(fontSize: 11.5)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${line.screen} · ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}',
                maxLines: 1,
                style: SoftSaaSTypography.caption(b),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
