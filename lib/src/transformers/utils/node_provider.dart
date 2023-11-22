import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NodeProvider extends InheritedWidget {
  final BaseNode node;

  const NodeProvider({
    super.key,
    required Widget child,
    required this.node,
  }) : super(child: child);

  static BaseNode of(BuildContext context) {
    final NodeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeProvider>();
    assert(provider != null, 'No NodeProvider found in context');
    return provider!.node;
  }

  static BaseNode? maybeOf(BuildContext context) {
    final NodeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeProvider>();
    if (provider == null) return null;
    return provider.node;
  }

  static Object? getValue(BuildContext context) {
    final NodeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeProvider>();
    if (provider == null) return null;
    return getValueForNode(provider.node);
  }

  @override
  bool updateShouldNotify(covariant NodeProvider oldWidget) {
    return oldWidget.node != node;
  }

  static Object? getValueForNode(BaseNode node) {
    return switch (node) {
      TextFieldNode node => node.initialText,
      SwitchNode node => node.value,
      RadioNode node => node.value,
      CheckboxNode node => node.value,
      SliderNode node => node.value,
      _ => null,
    };
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('id', node.id));
    properties.add(StringProperty('name', node.name));
  }
}
