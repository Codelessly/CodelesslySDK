import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../transformers/node_registry.dart';
import '../transformers/utils/property_value_delegate.dart';
import '../transformers/node_transformer.dart';
import '../transformers/passive_transformer_manager.dart';
import '../utils/observable.dart';
import 'codelessly_context.dart';

/// Handles a [CallFunctionAction] from a node in a standalone tree.
///
/// [name] is the action's function name; [params] have already had variable
/// expressions substituted by the SDK's existing action runner.
typedef CodelessNodeAction = FutureOr<void> Function(
  String name,
  Map<String, dynamic> params,
);

/// Renders Codelessly nodes directly, without a published layout or Firebase.
///
/// [nodes] is keyed by node id and [rootId] identifies the entry node. Parent
/// links are derived from each parent's `children` list. Pass [variables] keyed
/// by variable id (their names are used in bindings), and [data] for `${data}`
/// bindings and initial values. Changes to these inputs require a new map or
/// widget rebuild; changing a variable at runtime through an SDK action uses
/// the existing observable variable pipeline.
///
/// [onAction] receives enabled [CallFunctionAction] reactions, including
/// substituted parameters. Other reaction types are rejected before rendering;
/// standalone trees cannot execute native actions.
/// Host this widget under a MaterialApp for Material widgets and navigation.
class CodelessNodeTreeView extends StatefulWidget {
  const CodelessNodeTreeView({
    super.key,
    required this.nodes,
    required this.rootId,
    this.data = const {},
    this.variables = const {},
    this.theme,
    this.onAction,
    this.previewNativePaywallActions = false,
  });

  final Map<String, BaseNode> nodes;
  final String rootId;
  final Map<String, dynamic> data;
  final Map<String, VariableData> variables;
  final ThemeData? theme;
  final CodelessNodeAction? onAction;

  /// Editor-only inert paywall preview. Native actions are stripped from a
  /// cloned node tree; this never dispatches a purchase, restore or legal URL.
  final bool previewNativePaywallActions;

  @override
  State<CodelessNodeTreeView> createState() => _CodelessNodeTreeViewState();
}

class _CodelessNodeTreeViewState extends State<CodelessNodeTreeView> {
  final NodeRegistry _registry = NodeRegistry();
  late final PassiveNodeTransformerManager _manager =
      PassiveNodeTransformerManager(
        _registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) =>
            const SizedBox.shrink(),
      );
  CodelesslyContext? _context;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CodelessNodeTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes ||
        oldWidget.rootId != widget.rootId ||
        oldWidget.variables != widget.variables) {
      _load();
    } else if (oldWidget.data != widget.data) {
      final context = _context!;
      context.data = widget.data;
      for (final variable in widget.variables.values) {
        final current = context.variables[variable.id];
        if (current == null) continue;
        final previous = oldWidget.data.containsKey(variable.name)
            ? oldWidget.data[variable.name]
            : variable.value;
        final next = widget.data.containsKey(variable.name)
            ? widget.data[variable.name]
            : variable.value;
        // A user-edited field wins over an unrelated data refresh.
        if (current.value.value == previous && previous != next) {
          current.value = variable.copyWith(value: next);
        }
      }
    }
  }

  void _load() {
    if (!widget.nodes.containsKey(widget.rootId)) {
      throw ArgumentError.value(widget.rootId, 'rootId', 'Missing root node');
    }
    for (final entry in widget.nodes.entries) {
      if (entry.key != entry.value.id) {
        throw ArgumentError(
          'Node map key ${entry.key} does not match node id ${entry.value.id}',
        );
      }
    }
    // Reject native actions even on currently unreachable nodes. The editor
    // may opt into an inert clone of paywall actions, not arbitrary actions.
    for (final node in widget.nodes.values) {
      if (node is ReactionMixin) {
        for (final reaction in (node as ReactionMixin).reactions) {
          if (reaction.action is! CallFunctionAction &&
              !(widget.previewNativePaywallActions && reaction.action is PaywallAction)) {
            throw ArgumentError(
              'Standalone tree rejects action '
              '${reaction.action.type} on node ${node.id}',
            );
          }
        }
      }
    }
    final old = _context;
    final previewNodes = widget.previewNativePaywallActions
        ? <String, BaseNode>{
            for (final entry in widget.nodes.entries)
              entry.key: _withoutNativeActions(entry.value),
          }
        : widget.nodes;
    _registry.setNodes(previewNodes);
    final nodes = _registry.getNodes();
    final allNodes = nodes.values.toList();
    for (final node in allNodes) {
      node.parentID = resolveParentNodeIDs(node: node, nodes: allNodes);
    }
    final context = CodelesslyContext.empty()
      ..data = widget.data
      ..variables.addAll({
        for (final variable in widget.variables.values)
          variable.id: Observable(
            widget.data.containsKey(variable.name)
                ? variable.copyWith(value: widget.data[variable.name])
                : variable,
          ),
      });
    for (final node in nodes.values) {
      if (node is ReactionMixin) {
        for (final reaction in (node as ReactionMixin).reactions) {
          if (reaction.action is! CallFunctionAction) continue;
          final name = (reaction.action as CallFunctionAction).name;
          context.functions[name] = (_, _, params) =>
              widget.onAction?.call(name, params);
        }
      }
    }
    _context = context;
    // The old context remains alive until the provider stops exposing it.
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  BaseNode _withoutNativeActions(BaseNode node) {
    if (node is! ReactionMixin || (node as ReactionMixin).reactions.isEmpty) {
      return node;
    }
    final json = Map<String, dynamic>.from(node.toJson());
    json['reactions'] = [
      for (final reaction in (node as ReactionMixin).reactions)
        if (reaction.action is CallFunctionAction) reaction.toJson(),
    ];
    return NodeJsonConverter().fromJson(json)!;
  }

  @override
  void dispose() {
    _context?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget tree = ChangeNotifierProvider<CodelesslyContext>.value(
      value: _context!,
      child: Builder(
        builder: (context) => _manager.buildWidgetFromNode(
          _registry.getNodeByID(widget.rootId),
          context,
          settings: const WidgetBuildSettings(
            debugLabel: 'node tree',
            nullSubstitutionMode: NullSubstitutionMode.emptyString,
          ),
        ),
      ),
    );
    if (widget.theme != null) tree = Theme(data: widget.theme!, child: tree);
    return tree;
  }
}
