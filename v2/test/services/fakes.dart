// Fakes of the runtime's seams for service tests: values in a map and an
// expression engine that reads `${path}` from them.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';

class MapScope extends ChangeNotifier implements ValueScope {
  MapScope(this.values);

  final Map<String, Object?> values;

  @override
  ValueScope? get parent => null;

  @override
  Object? read(String path) {
    Object? current = values;
    for (final part in path.split('.')) {
      if (current is! Map) return null;
      current = current[part];
    }
    return current;
  }
}

class FakeExpressions implements ExpressionEngine {
  static final _pattern = RegExp(r'\$\{([^{}]*)\}');

  @override
  Object? evaluate(String expression, ValueScope scope) {
    final m = _pattern.firstMatch(expression.trim());
    return m == null ? expression : scope.read(m[1]!.trim());
  }

  @override
  String interpolate(String text, ValueScope scope) =>
      text.replaceAllMapped(_pattern, (m) => '${scope.read(m[1]!.trim()) ?? ''}');

  @override
  (Node, Set<String>) resolve(Node node, ValueScope scope) => (node, const {});
}
