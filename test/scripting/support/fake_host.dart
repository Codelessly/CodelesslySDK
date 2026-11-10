import 'package:codelessly_sdk/codelessly_sdk.dart';

/// A [ScriptHost] with sample data that records what scripts do.
class FakeHost implements ScriptHost {
  /// Variables by name.
  final Map<String, Object?> vars;

  /// Input values by node id.
  final Map<String, Object?> nodes;

  /// Variables that are computed and can't be set.
  final Set<String> computed;

  /// The host calls made, as `name(args)`.
  final List<String> calls = [];

  /// Creates a [FakeHost].
  FakeHost({
    Map<String, Object?>? vars,
    Map<String, Object?>? nodes,
    this.computed = const {},
  }) : vars = vars ?? {},
       nodes = nodes ?? {};

  @override
  Map<String, Object?> variables() => Map.of(vars);

  @override
  Map<String, Object?> nodeValues() => Map.of(nodes);

  @override
  void setVariable(String name, Object? value) {
    if (computed.contains(name)) {
      throw ScriptHostError(
        '"$name" is computed from a formula and can\'t be set.',
      );
    }
    vars[name] = value;
  }

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    calls.add('$name(${args.join(', ')})');
    switch (name) {
      case 'callApi':
        if (args.first == 'broken') throw const ScriptHostError('Network down');
        final Map inputs = args[1] as Map? ?? {};
        return {
          'status': 200,
          'ok': true,
          'body': {'city': inputs['city'], 'temp': 21},
        };
      case 'runAction':
        return {'ran': (args.first as Map)['type']};
      case 'cloudData':
        return {
          'docs': [
            {'id': 'a'},
            {'id': 'b'},
          ],
        };
      case 'delay':
        await Future<void>.delayed(
          Duration(milliseconds: (args.first as num).toInt()),
        );
        return null;
      default:
        return null;
    }
  }
}
