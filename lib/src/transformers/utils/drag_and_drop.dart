import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

/// The id of a list item or payload value: a map's `id`, else the value
/// itself as text.
String dragItemId(Object? value) => switch (value) {
  final Map map when map['id'] != null => FormulaEvaluator.stringify(map['id']),
  _ => FormulaEvaluator.stringify(value),
};

/// The ids a payload carries: each element of a list, or the value.
List<String> dragPayloadIds(Object? data) => switch (data) {
  final Iterable list => [for (final Object? v in list) dragItemId(v)],
  null => const [],
  _ => [dragItemId(data)],
};

/// A drag in progress.
class DragSession {
  /// The draggable's group.
  final String group;

  /// The payload, as evaluated when the drag started.
  final Object? data;

  /// The ids the payload carries (see [dragPayloadIds]).
  final List<String> ids;

  /// The key of the drop target the drag started in, or ''.
  final String source;

  /// The size of the dragged node.
  final Size size;

  /// Where the pointer holds the dragged node, from its top left.
  Offset grab = Offset.zero;

  /// The drop target under the pointer, or null.
  Object? overTarget;

  /// The key of [overTarget], or ''.
  String over = '';

  /// Where in [overTarget]'s list the drop would land: the index among the
  /// items that aren't being dragged, the raw index of the item it lands
  /// before (the list's length at the end), that item and its id.
  int index = 0;
  int? rawBefore;
  Object? before;
  String beforeId = '';

  /// Whether [overTarget] accepts the drop (its `acceptIf`).
  bool accepted = false;

  DragSession({
    required this.group,
    required this.data,
    required this.source,
    required this.size,
  }) : ids = dragPayloadIds(data);

  /// Number of things dragged.
  int get count => data is Iterable ? ids.length : 1;

  /// What `${drag}` reads.
  Map<String, Object?> toMap({bool active = true}) => {
    'active': active,
    'group': group,
    'data': data,
    'ids': ids,
    'count': count,
    'source': source,
    'over': over,
    'index': index,
    'beforeId': beforeId,
    'before': before,
    'accepted': accepted,
    'width': size.width,
    'height': size.height,
  };
}

/// The drag-and-drop state of a layout: the drag in progress, what
/// `${drag}` reads, and what bindings to `drag` listen to.
class DragAndDropController extends ChangeNotifier {
  DragSession? _session;
  Map<String, Object?>? _last;

  /// What `${drag}` reads on the editor's design canvas, so drag styles
  /// can be designed without dragging. Null outside the editor.
  static Map<String, Object?>? preview;

  /// The value of `${drag}` when nothing is being dragged.
  static const Map<String, Object?> idle = {
    'active': false,
    'group': '',
    'data': null,
    'ids': <String>[],
    'count': 0,
    'source': '',
    'over': '',
    'index': 0,
    'beforeId': '',
    'before': null,
    'accepted': false,
    'width': 0.0,
    'height': 0.0,
  };

  /// The drag in progress, or null.
  DragSession? get session => _session;

  /// What `${drag}` reads: the drag in progress, else the last drop (with
  /// `active` false, so a drop's actions can still read it), else [idle].
  Map<String, Object?> get value =>
      _session?.toMap() ?? _last ?? preview ?? idle;

  /// Starts [session].
  void start(DragSession session) {
    _session = session;
    _last = null;
    notifyListeners();
  }

  /// Tells listeners the session changed.
  void changed() => notifyListeners();

  /// Ends the drag in progress; [dropped] keeps its values for `${drag}`.
  void end({bool dropped = false}) {
    final DragSession? session = _session;
    if (session == null) return;
    _session = null;
    _last = dropped ? session.toMap(active: false) : null;
    notifyListeners();
  }

  /// Whether a node whose payload is [ids] is part of the drag.
  bool isDragging(List<String> ids) {
    final DragSession? s = _session;
    return s != null && ids.any(s.ids.contains);
  }
}

/// What a [Draggable] carries between a [DragSourceBox] and a
/// [DropTargetBox]. A draggable's data is fixed when it builds but the
/// payload is made when the drag starts, so this holder is filled in then.
class CodelesslyDragPayload {
  late DragSession session;
  late DragAndDropController controller;

  /// Fires the source's `dragCancel` reactions.
  VoidCallback cancel = () {};
}

/// Evaluates [text] (`${...}` path, `${= ...}` formula or text with paths)
/// to a value in [context].
Object? evaluateDragValue(String text, BuildContext context) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final ScopedValues scopedValues = ScopedValues.of(context);
  if (FormulaEvaluator.exactExpression(trimmed) != null ||
      RegExp(r'^\$\{[^{}]*\}$').hasMatch(trimmed)) {
    return PropertyValueDelegate.getVariableValueFromPath<Object>(
      trimmed,
      scopedValues: scopedValues,
    );
  }
  return PropertyValueDelegate.substituteVariables(
    trimmed,
    scopedValues: scopedValues,
    nullSubstitutionMode: NullSubstitutionMode.emptyString,
  );
}

/// Makes [child] (a node's widget) draggable as [model] says.
class DragSourceBox extends StatefulWidget {
  final BaseNode node;
  final DraggableModel model;
  final Widget child;

  /// Builds the node drawn under the pointer when the model names one.
  final Widget Function(BuildContext context, String nodeId)? buildNode;

  const DragSourceBox({
    super.key,
    required this.node,
    required this.model,
    required this.child,
    this.buildNode,
  });

  @override
  State<DragSourceBox> createState() => _DragSourceBoxState();
}

class _DragSourceBoxState extends State<DragSourceBox> {
  Size _size = Size.zero;
  final CodelesslyDragPayload _holder = CodelesslyDragPayload();
  CodelesslyDragPayload? _payload;

  DragAndDropController get controller =>
      context.read<CodelesslyContext>().dragAndDrop;

  /// The ids this node's payload carries now.
  List<String> get _ownIds =>
      dragPayloadIds(evaluateDragValue(widget.model.data, context));

  List<Reaction> _reactions(TriggerType type) => [
    if (widget.node case final ReactionMixin node)
      for (final reaction in node.reactions)
        if (reaction.trigger.type == type && reaction.action.enabled) reaction,
  ];

  CodelesslyDragPayload _start(Offset grab) {
    final DragSession session = DragSession(
      group: widget.model.group,
      data: evaluateDragValue(widget.model.data, context),
      source: DropTargetScope.maybeOf(context)?.key ?? '',
      size: _size,
    )..grab = grab;
    return _holder
      ..session = session
      ..controller = controller
      ..cancel = () {
        if (!mounted) return;
        FunctionsRepository.triggerAction(
          context,
          TriggerType.dragCancel,
          reactions: _reactions(TriggerType.dragCancel),
          result: session.toMap(active: false),
        );
      };
  }

  void _started() {
    final CodelesslyDragPayload? payload = _payload;
    if (payload == null) return;
    HapticFeedback.selectionClick();
    payload.controller.start(payload.session);
    final List<Reaction> onStart = _reactions(TriggerType.dragStart);
    if (onStart.isNotEmpty) {
      FunctionsRepository.triggerAction(
        context,
        TriggerType.dragStart,
        reactions: onStart,
        result: payload.session.toMap(),
      );
    }
  }

  void _ended(bool accepted) {
    final CodelesslyDragPayload? payload = _payload;
    _payload = null;
    if (payload == null) return;
    // A drop on a target ends the session there.
    if (accepted && !identical(payload.controller.session, payload.session)) {
      return;
    }
    payload.controller.end();
    payload.cancel();
  }

  /// The node drawn under the pointer, in the app's overlay. What the node
  /// reads (its list item, the layout's context, themes) is taken from the
  /// node's own place in the tree, not from the overlay's.
  Widget _feedback(BuildContext overlayContext) {
    final BuildContext context = this.context;
    final DraggableModel model = widget.model;
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final Codelessly? codelessly = context.read<Codelessly?>();
    final IndexedItem? item = IndexedItemProvider.maybeOf(context);
    final CapturedThemes themes = InheritedTheme.capture(
      from: context,
      to: Navigator.maybeOf(context, rootNavigator: true)?.context,
    );
    final TextDirection direction =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    final Widget content =
        model.feedbackNodeId.isNotEmpty && widget.buildNode != null
        ? Builder(
            builder: (context) =>
                widget.buildNode!(context, model.feedbackNodeId),
          )
        : SizedBox.fromSize(size: _size, child: widget.child);
    final double radius = switch (widget.node) {
      final CornerMixin node => node.cornerRadius.tl.x,
      _ => 0,
    };

    Widget feedback = Opacity(
      opacity: model.feedbackOpacity.clamp(0, 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: model.feedbackElevation <= 0
              ? null
              : [
                  BoxShadow(
                    color: const Color(0x2E14171C),
                    blurRadius: model.feedbackElevation,
                    offset: Offset(0, model.feedbackElevation / 2),
                  ),
                ],
        ),
        child: content,
      ),
    );
    if (model.feedbackScale != 1 || model.feedbackRotation != 0) {
      feedback = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(model.feedbackRotation * math.pi / 180)
          ..scaleByDouble(model.feedbackScale, model.feedbackScale, 1, 1),
        child: feedback,
      );
    }
    // The feedback is drawn in the app's overlay, outside this layout:
    // take what the node reads along.
    feedback = MultiProvider(
      providers: [
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
        ),
        if (codelessly != null) Provider<Codelessly>.value(value: codelessly),
        Provider<Codelessly?>.value(value: codelessly),
      ],
      child: Directionality(
        textDirection: direction,
        child: Material(
          type: MaterialType.transparency,
          child: item == null
              ? feedback
              : IndexedItemProvider(item: item, child: feedback),
        ),
      ),
    );
    return themes.wrap(IgnorePointer(child: feedback));
  }

  Offset _anchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    _size = box.size;
    final Offset grab = box.globalToLocal(position);
    _payload = _start(grab);
    return grab;
  }

  @override
  Widget build(BuildContext context) {
    final DraggableModel model = widget.model;
    final DragAndDropController controller = this.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final DragSession? session = controller.session;
        final bool dragged = session != null && controller.isDragging(_ownIds);
        Widget shown = widget.child;
        if (dragged) {
          shown = switch (model.whileDragging) {
            // Collapses while over a target, so the slot there is the only
            // place it shows; ghosts elsewhere so it can be found again.
            DragSourceStyle.hidden when session.overTarget != null =>
              const SizedBox.shrink(),
            DragSourceStyle.hidden || DragSourceStyle.ghost => Opacity(
              opacity: model.ghostOpacity.clamp(0, 1),
              child: IgnorePointer(child: widget.child),
            ),
            DragSourceStyle.keep => widget.child,
          };
        }
        final Axis? axis = switch (model.axis) {
          DragAxis.free => null,
          DragAxis.horizontal => Axis.horizontal,
          DragAxis.vertical => Axis.vertical,
        };
        final bool longPress = switch (model.start) {
          DragStart.press => false,
          DragStart.longPress => true,
          DragStart.auto => const {
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.fuchsia,
          }.contains(Theme.of(context).platform),
        };
        final Widget feedback = Builder(builder: _feedback);
        void onEnd(DraggableDetails details) => _ended(details.wasAccepted);
        void onCanceled(Velocity _, Offset _) => _ended(false);
        void onUpdate(DragUpdateDetails details) =>
            DropTargetBox.autoScroll(details.globalPosition);
        void onEnd2(DraggableDetails details) {
          DropTargetBox.stopAutoScroll();
          onEnd(details);
        }

        final Widget draggable = longPress
            ? LongPressDraggable<CodelesslyDragPayload>(
                data: _holder,
                axis: axis,
                feedback: feedback,
                dragAnchorStrategy: (d, c, p) => _anchor(d, c, p),
                childWhenDragging: shown,
                onDragStarted: _started,
                onDragEnd: onEnd2,
                onDraggableCanceled: onCanceled,
                onDragUpdate: onUpdate,
                delay: const Duration(milliseconds: 300),
                child: shown,
              )
            : Draggable<CodelesslyDragPayload>(
                data: _holder,
                axis: axis,
                feedback: feedback,
                dragAnchorStrategy: (d, c, p) => _anchor(d, c, p),
                childWhenDragging: shown,
                onDragStarted: _started,
                onDragEnd: onEnd2,
                onDraggableCanceled: onCanceled,
                onDragUpdate: onUpdate,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: shown,
                ),
              );
        return draggable;
      },
    );
  }
}

/// The item of a list inside a drop target, registered so the target can
/// tell where among the items the pointer is.
class _ListEntry {
  final int index;
  final Object? value;
  final GlobalKey key;
  _ListEntry(this.index, this.value, this.key);
}

/// Gives the nodes inside a [DropTargetBox] access to it: lists register
/// their items and read where the slot goes.
class DropTargetScope extends InheritedWidget {
  final DropTargetBoxState state;

  const DropTargetScope({super.key, required this.state, required super.child});

  /// The nearest drop target above [context], if any.
  static DropTargetBoxState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DropTargetScope>()?.state;

  /// The nearest drop target above [context] whose list is [listNodeId].
  static DropTargetBoxState? forList(BuildContext context, String listNodeId) {
    DropTargetBoxState? found;
    context.visitAncestorElements((element) {
      final Widget widget = element.widget;
      if (widget is DropTargetScope &&
          widget.state.widget.model.listNodeId == listNodeId) {
        found = widget.state;
        return false;
      }
      return true;
    });
    return found;
  }

  @override
  bool updateShouldNotify(DropTargetScope oldWidget) =>
      state != oldWidget.state;
}

/// Makes [child] a drop target as [model] says.
class DropTargetBox extends StatefulWidget {
  final BaseNode node;
  final DropTargetModel model;
  final Widget child;

  const DropTargetBox({
    super.key,
    required this.node,
    required this.model,
    required this.child,
  });

  /// Scrollers of the scroll views under drop targets and their lists.
  static final Set<EdgeDraggingAutoScroller> _scrollers = {};
  static final Map<ScrollableState, EdgeDraggingAutoScroller> _byScrollable =
      {};

  /// Scrolls the scroll views around the target under [position], and its
  /// list, when [position] is near one of their edges.
  static void autoScroll(Offset position) {
    final Rect probe = Rect.fromCenter(center: position, width: 2, height: 2);
    for (final EdgeDraggingAutoScroller scroller in _scrollers.toList()) {
      final ScrollableState scrollable = scroller.scrollable;
      if (!scrollable.mounted) {
        _scrollers.remove(scroller);
        _byScrollable.remove(scrollable);
        continue;
      }
      final RenderBox? box =
          scrollable.context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final Rect area = box.localToGlobal(Offset.zero) & box.size;
      if (!area.inflate(8).contains(position)) {
        scroller.stopAutoScroll();
        continue;
      }
      scroller.startAutoScrollIfNecessary(probe);
    }
  }

  /// Registers [scrollable] for [autoScroll].
  static void watchScrollable(ScrollableState scrollable) {
    if (_byScrollable.containsKey(scrollable)) return;
    final scroller = EdgeDraggingAutoScroller(
      scrollable,
      velocityScalar: 18,
      onScrollViewScrolled: () {},
    );
    _byScrollable[scrollable] = scroller;
    _scrollers.add(scroller);
  }

  /// Stops every auto-scroll (the drag ended).
  static void stopAutoScroll() {
    for (final scroller in _scrollers) {
      scroller.stopAutoScroll();
    }
  }

  @override
  State<DropTargetBox> createState() => DropTargetBoxState();
}

class DropTargetBoxState extends State<DropTargetBox> {
  final Map<Object, _ListEntry> _entries = {};
  final Map<Object, GlobalKey> _keys = {};
  Axis _listAxis = Axis.vertical;
  Timer? _hoverTimer;
  bool _entered = false;

  DragAndDropController get controller =>
      context.read<CodelesslyContext>().dragAndDrop;

  /// This target's key, as `drag.over` reads it.
  String get key {
    final String text = widget.model.key.trim();
    if (text.isEmpty) return widget.node.id;
    return FormulaEvaluator.stringify(evaluateDragValue(text, context));
  }

  /// Whether a drag is over this target.
  bool get isOver => identical(controller.session?.overTarget, this);

  /// Wraps a list item: registers it so the pointer can be placed among the
  /// items.
  Widget registerItem({
    required Object identity,
    required int index,
    required Object? value,
    required Axis axis,
    required Widget child,
  }) {
    _listAxis = axis;
    final GlobalKey key = _keys.putIfAbsent(identity, GlobalKey.new);
    _entries[identity] = _ListEntry(index, value, key);
    return KeyedSubtree(key: key, child: child);
  }

  /// Watches the list's scroll view for auto-scrolling.
  void registerListScrollable(BuildContext itemContext) {
    final ScrollableState? scrollable = Scrollable.maybeOf(itemContext);
    if (scrollable != null) DropTargetBox.watchScrollable(scrollable);
  }

  /// Where the slot goes: the raw index it goes before (or null for none),
  /// while a drag is over this target.
  int? get slotBefore {
    final DragSession? session = controller.session;
    if (session == null || !identical(session.overTarget, this)) return null;
    if (widget.model.slot == DropSlot.none) return null;
    return session.rawBefore;
  }

  /// Builds the slot shown where the drop would land.
  Widget buildSlot(
    BuildContext context,
    Axis axis,
    Widget Function(BuildContext context, String nodeId)? buildNode,
  ) {
    final DragSession? session = controller.session;
    final Size size = session?.size ?? Size.zero;
    final Widget sized = SizedBox(
      width: axis == Axis.horizontal ? size.width : null,
      height: axis == Axis.vertical ? size.height : null,
      child:
          widget.model.slot == DropSlot.node &&
              widget.model.slotNodeId.isNotEmpty &&
              buildNode != null
          ? buildNode(context, widget.model.slotNodeId)
          : null,
    );
    return KeyedSubtree(
      key: const ValueKey('codelessly-drop-slot'),
      child: sized,
    );
  }

  Rect? _rectOf(GlobalKey key) {
    final RenderObject? box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Places the pointer at [position] among the list's items.
  void _place(DragSession session, Offset position) {
    final List<_ListEntry> entries =
        _entries.values.where((e) => e.key.currentContext != null).toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    int index = 0;
    _ListEntry? before;
    for (final _ListEntry entry in entries) {
      if (session.ids.contains(dragItemId(entry.value))) continue;
      final Rect? rect = _rectOf(entry.key);
      if (rect == null) continue;
      final bool ahead = _listAxis == Axis.vertical
          ? position.dy < rect.center.dy
          : position.dx < rect.center.dx;
      if (ahead) {
        before = entry;
        break;
      }
      index++;
    }
    session.index = index;
    session.before = before?.value;
    session.beforeId = before == null ? '' : dragItemId(before.value);
    session.rawBefore =
        before?.index ??
        (entries.isEmpty
            ? 0
            : entries.map((e) => e.index).reduce(math.max) + 1);
  }

  bool _evaluateAccept() {
    final String condition = widget.model.acceptIf.trim();
    if (condition.isEmpty) return true;
    final Object? value = evaluateDragValue(condition, context);
    return value == true || value == 'true';
  }

  void _move(CodelesslyDragPayload payload, Offset position) {
    final DragSession session = payload.session;
    final String oldOver = session.over;
    final int? oldBefore = session.rawBefore;
    final bool oldAccepted = session.accepted;
    final bool entering = !identical(session.overTarget, this);
    session.overTarget = this;
    session.over = key;
    if (widget.model.listNodeId.isNotEmpty) {
      _place(session, position);
    } else {
      session.index = 0;
      session.rawBefore = null;
      session.before = null;
      session.beforeId = '';
    }
    session.accepted = _evaluateAccept();
    if (entering ||
        oldOver != session.over ||
        oldBefore != session.rawBefore ||
        oldAccepted != session.accepted) {
      payload.controller.changed();
    }
    if (entering && !_entered) {
      _entered = true;
      _fire(TriggerType.dragEnter, session.toMap());
      if (widget.model.hoverDelayMs > 0) {
        _hoverTimer?.cancel();
        _hoverTimer = Timer(
          Duration(milliseconds: widget.model.hoverDelayMs),
          () {
            if (mounted &&
                identical(payload.controller.session?.overTarget, this)) {
              _fire(TriggerType.dragHover, session.toMap());
            }
          },
        );
      }
    }
  }

  void _leave(CodelesslyDragPayload payload) {
    _hoverTimer?.cancel();
    _entered = false;
    final DragSession session = payload.session;
    if (!identical(session.overTarget, this)) return;
    session
      ..overTarget = null
      ..over = ''
      ..accepted = false
      ..rawBefore = null;
    payload.controller.changed();
    _fire(TriggerType.dragExit, session.toMap());
  }

  void _drop(CodelesslyDragPayload payload) {
    _hoverTimer?.cancel();
    _entered = false;
    DropTargetBox.stopAutoScroll();
    final DragSession session = payload.session;
    final bool accepted =
        identical(session.overTarget, this) && session.accepted;
    final Map<String, Object?> result = session.toMap(active: false)
      ..['key'] = session.over;
    payload.controller.end(dropped: accepted);
    if (accepted) {
      _fire(TriggerType.drop, result);
    } else {
      payload.cancel();
    }
  }

  void _fire(TriggerType type, Map<String, Object?> result) {
    if (!mounted) return;
    final List<Reaction> reactions = [
      if (widget.node case final ReactionMixin node)
        for (final reaction in node.reactions)
          if (reaction.trigger.type == type && reaction.action.enabled)
            reaction,
    ];
    if (reactions.isEmpty) return;
    FunctionsRepository.triggerAction(
      context,
      type,
      reactions: reactions,
      result: result,
    );
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollableState? around = Scrollable.maybeOf(context);
    if (around != null) DropTargetBox.watchScrollable(around);
    return DropTargetScope(
      state: this,
      child: DragTarget<CodelesslyDragPayload>(
        // Asked once when the drag reaches the target, which for the target
        // the drag starts in is before the session is started.
        onWillAcceptWithDetails: (details) =>
            widget.model.acceptsGroup(details.data.session.group),
        onMove: (details) {
          final CodelesslyDragPayload payload = details.data;
          if (!widget.model.acceptsGroup(payload.session.group)) return;
          _move(payload, details.offset + payload.session.grab);
        },
        onLeave: (payload) {
          if (payload != null) _leave(payload);
        },
        onAcceptWithDetails: (details) => _drop(details.data),
        builder: (context, _, _) => widget.child,
      ),
    );
  }
}
