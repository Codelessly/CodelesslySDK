// The pagination node (SDK 8.x's PassivePaginationWidget): page controls
// for a list's pagination, as an island in the node's fit box.
//
// TODO(v2): pagination controllers (SDK 8.x's PaginationController and
// PaginationRegistry, data/pagination_controller.dart) aren't ported yet,
// so the controls always show their preview state (page 1 of 10, 200 items)
// and are disabled, as SDK 8.x's are with no controller of that name.
import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart' show Node, PaginationProps;
import 'package:flutter/material.dart';

import '../render/convert.dart';
import '../render/recipe.dart';

/// The pagination node: fit box → its controls.
void paginationRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  chain.add(b.island('pagination', (context) => PaginationControls(node: n)));
}

/// What a pagination node shows: the controller's state, or the preview's.
class PaginationState {
  const PaginationState({
    this.page = 1,
    this.pageCount = 10,
    this.totalCount = 200,
    this.from = 1,
    this.to = 20,
    this.hasMore = true,
    this.pageSize = 20,
    this.pageSizeOptions = const [10, 20, 50, 100],
  });

  final int page;
  final int? pageCount, totalCount;
  final int from, to, pageSize;
  final bool hasMore;
  final List<int> pageSizeOptions;

  /// The preview (no controller).
  static const preview = PaginationState();
}

WrapAlignment _wrapAlignment(api.WrapAlignment a) => WrapAlignment.values.byName(a.name);

/// A pagination node's controls: a summary, first/previous/page numbers/
/// next/last buttons and a page size select, in a wrap.
class PaginationControls extends StatelessWidget {
  const PaginationControls({super.key, required this.node, this.state = PaginationState.preview, this.controlled = false});

  final Node node;
  final PaginationState state;

  /// Whether a controller moves (enables the buttons).
  final bool controlled;

  @override
  Widget build(BuildContext context) {
    final n = node;
    final s = state;
    final enabled = controlled && n.prop(PaginationProps.enabled);
    final style = TextStyle(
      fontSize: n.prop(PaginationProps.fontSize),
      fontWeight: FontWeight.values[(n.prop(PaginationProps.fontWeight) ~/ 100 - 1).clamp(0, 8)],
      color: n.prop(PaginationProps.textColor).flutter,
    );
    Widget button(String label, {required bool canPress, bool active = false, String? semantics}) => PaginationButton(
          node: n,
          label: label,
          style: style,
          active: active,
          enabled: enabled && canPress,
          semanticsLabel: semantics,
        );
    final spacing = n.prop(PaginationProps.spacing);
    final pageCount = s.pageCount;
    final buttons = [
      if (n.prop(PaginationProps.showFirstLast))
        button(n.prop(PaginationProps.firstLabel), semantics: 'First page', canPress: s.page > 1),
      if (n.prop(PaginationProps.showPrevNext))
        button(n.prop(PaginationProps.previousLabel), semantics: 'Previous page', canPress: s.page > 1),
      if (n.prop(PaginationProps.showPageNumbers))
        for (final number in PaginationProps.pageItems(
          page: s.page,
          pageCount: pageCount ?? s.page + (s.hasMore ? 1 : 0),
          siblingCount: n.prop(PaginationProps.siblingCount),
          boundaryCount: n.prop(PaginationProps.boundaryCount),
        ))
          if (number == null)
            SizedBox(
                width: n.prop(PaginationProps.buttonSize) * 0.75,
                child: Text('…', style: style, textAlign: TextAlign.center))
          else
            button('$number', semantics: 'Page $number', active: number == s.page, canPress: number != s.page),
      if (n.prop(PaginationProps.showPrevNext))
        button(n.prop(PaginationProps.nextLabel), semantics: 'Next page', canPress: s.hasMore),
      if (n.prop(PaginationProps.showFirstLast))
        button(n.prop(PaginationProps.lastLabel),
            semantics: 'Last page', canPress: pageCount != null && s.page < pageCount),
    ];
    final summary = n
        .prop(PaginationProps.summaryText)
        .replaceAll('{from}', '${s.from}')
        .replaceAll('{to}', '${s.to}')
        .replaceAll('{total}', s.totalCount == null ? 'many' : '${s.totalCount}')
        .replaceAll('{page}', '${s.page}')
        .replaceAll('{pageCount}', pageCount == null ? '?' : '$pageCount');
    final options = {...s.pageSizeOptions, s.pageSize}.toList()..sort();
    return Padding(
      padding: n.layout.padding.flutter,
      child: Wrap(
        alignment: _wrapAlignment(n.prop(PaginationProps.alignment)),
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: spacing * 3,
        runSpacing: spacing,
        children: [
          if (n.prop(PaginationProps.showSummary)) Text(summary, style: style),
          Wrap(spacing: spacing, runSpacing: spacing, crossAxisAlignment: WrapCrossAlignment.center, children: buttons),
          if (n.prop(PaginationProps.showPageSize))
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(n.prop(PaginationProps.pageSizeLabel), style: style),
              SizedBox(width: spacing * 2),
              DropdownButton<int>(
                value: s.pageSize,
                style: style,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [for (final o in options) DropdownMenuItem(value: o, child: Text('$o'))],
                onChanged: enabled ? (_) {} : null,
              ),
            ]),
        ],
      ),
    );
  }
}

/// One button of a pagination node (SDK 8.x's `PaginationButton`).
class PaginationButton extends StatelessWidget {
  const PaginationButton({
    super.key,
    required this.node,
    required this.label,
    required this.style,
    required this.active,
    required this.enabled,
    this.semanticsLabel,
    this.onPressed,
  });

  final Node node;
  final String label;
  final TextStyle style;
  final bool active, enabled;
  final String? semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final n = node;
    final radius = BorderRadius.circular(n.prop(PaginationProps.cornerRadius));
    final background = active ? n.prop(PaginationProps.activeColor).flutter : n.prop(PaginationProps.buttonColor)?.flutter;
    final borderColor = n.prop(PaginationProps.borderColor);
    final borderWidth = n.prop(PaginationProps.borderWidth);
    final size = n.prop(PaginationProps.buttonSize);
    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || active ? 1 : n.prop(PaginationProps.disabledOpacity),
        child: Material(
          color: background ?? Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: active || borderColor.alpha == 0 || borderWidth <= 0
                ? BorderSide.none
                : BorderSide(color: borderColor.flutter, width: borderWidth),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: size, minHeight: size),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: active
                        ? style.copyWith(color: n.prop(PaginationProps.activeTextColor).flutter, fontWeight: FontWeight.w600)
                        : style,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
