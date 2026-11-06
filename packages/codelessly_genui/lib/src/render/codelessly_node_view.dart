import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
// The action chain host runs the reactions a node fires; the SDK's own
// widget tests host nodes the same way.
// ignore: implementation_imports
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// A two-way binding between one property of a Codelessly node and an A2UI
/// data path.
@immutable
class NodePropertyBinding {
  const NodePropertyBinding({
    required this.value,
    required this.type,
    required this.write,
  });

  /// The current value, as A2UI resolved it.
  final Object? value;

  /// The Codelessly variable type the SDK widget reads and writes.
  final VariableType type;

  /// Writes a value the user set back to the A2UI data model.
  final void Function(Object? value) write;
}

/// Renders one Codelessly node, given as node JSON, with the Codelessly
/// SDK's own widget for it (`PassiveNodeTransformerManager`).
///
/// [bindings] connect node properties to the A2UI data model. Each one
/// becomes a Codelessly variable that the node's property is bound to
/// (`node.variables[property] = '${name}'`), so the SDK widget reads it
/// and, when the user changes the input, writes it the way it writes any
/// Codelessly variable; the view forwards those writes to A2UI.
///
/// [onTap] and [onCommit] are run by Codelessly reactions (`click`, and
/// `changed` or `changeEnd`), which call a function this view registers.
class CodelesslyNodeView extends StatefulWidget {
  const CodelesslyNodeView({
    super.key,
    required this.nodeJson,
    this.bindings = const {},
    this.onTap,
    this.onCommit,
    this.commitTrigger = TriggerType.changed,
  });

  final Map<String, Object?> nodeJson;
  final Map<String, NodePropertyBinding> bindings;
  final VoidCallback? onTap;
  final VoidCallback? onCommit;

  /// The Codelessly trigger that counts as committing a value: `changeEnd`
  /// for a slider (on release), `changed` for toggles and pickers,
  /// `submitted` for a text field.
  final TriggerType commitTrigger;

  @override
  State<CodelesslyNodeView> createState() => _CodelesslyNodeViewState();
}

class _CodelesslyNodeViewState extends State<CodelesslyNodeView> {
  final CodelesslyContext _context = CodelesslyContext.empty();
  final NodeRegistry _registry = NodeRegistry();
  late final PassiveNodeTransformerManager _manager =
      PassiveNodeTransformerManager(
        _registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
  final Map<String, VoidCallback> _listeners = {};
  bool _syncing = false;

  static String _variableName(String property) => 'genui_$property';

  @override
  void initState() {
    super.initState();
    _context.functions['genui_tap'] = (context, reference, params) =>
        widget.onTap?.call();
    _context.functions['genui_commit'] = (context, reference, params) =>
        widget.onCommit?.call();
    _syncVariables();
  }

  @override
  void didUpdateWidget(CodelesslyNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVariables();
  }

  /// Brings each binding's variable to the value A2UI resolved, without
  /// echoing it back as a write.
  void _syncVariables() {
    _syncing = true;
    try {
      for (final MapEntry<String, NodePropertyBinding> entry
          in widget.bindings.entries) {
        final String name = _variableName(entry.key);
        final Object? value = _toVariableValue(entry.value);
        final Observable<VariableData>? existing = _context.variables[name];
        if (existing == null) {
          final observable = Observable(
            VariableData(
              id: name,
              name: name,
              value: value,
              type: entry.value.type,
            ),
          );
          void listener() => _onVariableChanged(entry.key, observable);
          observable.addListener(listener);
          _listeners[name] = listener;
          _context.variables[name] = observable;
        } else if (existing.value.value != value) {
          existing.value = existing.value.copyWith(value: value);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  static Object? _toVariableValue(NodePropertyBinding binding) =>
      switch (binding.type) {
        VariableType.list => binding.value is List ? binding.value : const [],
        VariableType.boolean => binding.value == true,
        _ => binding.value,
      };

  void _onVariableChanged(String property, Observable<VariableData> o) {
    if (_syncing) return;
    final NodePropertyBinding? binding = widget.bindings[property];
    if (binding == null) return;
    binding.write(_parse(o.value.value, binding.type));
  }

  /// The SDK writes variables in their text form; this reads them back.
  static Object? _parse(Object? raw, VariableType type) {
    switch (type) {
      case VariableType.decimal:
      case VariableType.integer:
        if (raw is num) return raw;
        final double? d = double.tryParse('$raw');
        if (d == null) return null;
        return d == d.roundToDouble() && d.abs() < 1e15 ? d.toInt() : d;
      case VariableType.boolean:
        if (raw is bool) return raw;
        return '$raw'.toLowerCase() == 'true';
      case VariableType.list:
        if (raw is List) return [for (final item in raw) '$item'];
        final String s = '$raw'.trim();
        if (s.isEmpty || s == '[]') return <String>[];
        final String inner = s.startsWith('[') && s.endsWith(']')
            ? s.substring(1, s.length - 1)
            : s;
        return [
          for (final part in inner.split(','))
            part.trim().replaceAll(RegExp(r'^"|"$'), ''),
        ];
      default:
        return raw == null ? null : '$raw';
    }
  }

  BaseNode _buildNode() {
    final Map<String, Object?> json = {...widget.nodeJson};
    final BaseNode node = NodeJsonConverter.instance.fromJson(json)!;
    for (final String property in widget.bindings.keys) {
      node.variables[property] = '\${${_variableName(property)}}';
    }
    final List<Reaction> reactions = [
      if (widget.onTap != null)
        Reaction(
          trigger: TriggerModel(type: TriggerType.click),
          action: CallFunctionAction(name: 'genui_tap'),
        ),
      if (widget.onCommit != null)
        Reaction(
          trigger: TriggerModel(type: widget.commitTrigger),
          action: CallFunctionAction(name: 'genui_commit'),
        ),
    ];
    if (reactions.isNotEmpty && node is ReactionMixin) {
      (node as ReactionMixin).reactions = reactions;
    }
    return node;
  }

  @override
  void dispose() {
    for (final MapEntry<String, VoidCallback> entry in _listeners.entries) {
      _context.variables[entry.key]?.removeListener(entry.value);
    }
    _context.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BaseNode node = _buildNode();
    _registry.setNodes({node.id: node});
    return ChangeNotifierProvider<CodelesslyContext>.value(
      value: _context,
      child: ActionChainHost(
        child: Builder(
          builder: (context) => _manager.buildWidgetFromNode(
            node,
            context,
            settings: const WidgetBuildSettings(debugLabel: 'genui'),
          ),
        ),
      ),
    );
  }
}
