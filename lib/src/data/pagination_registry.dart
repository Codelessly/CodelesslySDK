import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../codelessly_sdk.dart';

/// The pagination controllers of a screen, by [PaginationModel.name], each
/// publishing its [PaginationController.state] into a map variable of that
/// name: `${contacts.page}`, `${contacts.items}`. Lists create theirs as
/// they build; Paginate actions and Pagination nodes find them by name.
class PaginationRegistry extends ChangeNotifier {
  final Map<String, PaginationController> _controllers = {};
  final Map<String, VoidCallback> _publishers = {};

  /// The variables the controllers write into, by id.
  Map<String, Observable<VariableData>>? _variables;

  /// The controller named [name], if a list created it.
  PaginationController? operator [](String name) => _controllers[name];

  /// The names of the controllers.
  Iterable<String> get names => _controllers.keys;

  /// The controller for [model], created (and published into [variables])
  /// the first time, and updated to follow [model] afterwards.
  PaginationController ensure(
    PaginationModel model, {
    Map<String, Observable<VariableData>>? variables,
  }) {
    if (variables != null) _variables = variables;
    final PaginationController? existing = _controllers[model.name];
    if (existing != null) {
      existing.updateModel(model);
      return existing;
    }
    final PaginationController controller = PaginationController(model: model);
    _controllers[model.name] = controller;
    void publisher() => publish(model.name);
    _publishers[model.name] = publisher;
    controller.addListener(publisher);
    _write(model.name, notify: false);
    // Nodes that find controllers by name (a Pagination node built before
    // its list) look again.
    _notifyLater();
    return controller;
  }

  /// Writes the state of [name] into its variable, now or, during a build,
  /// after the frame.
  void publish(String name) {
    if (_buildPhase) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _write(name));
    } else {
      _write(name);
    }
  }

  static bool get _buildPhase {
    try {
      return SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks;
    } catch (_) {
      return false;
    }
  }

  void _notifyLater() {
    if (_buildPhase) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  void _write(String name, {bool notify = true}) {
    final PaginationController? controller = _controllers[name];
    final Map<String, Observable<VariableData>>? variables = _variables;
    if (controller == null || variables == null) return;
    final Map<String, Object?> state = controller.publishedState;
    final Observable<VariableData>? existing = variables.values
        .where((notifier) => notifier.value.name == name)
        .firstOrNull;
    if (existing == null) {
      final RuntimeVariableData variable = RuntimeVariableData(
        name: name,
        type: VariableType.map,
        value: state,
      );
      variables[variable.id] = Observable(variable);
      return;
    }
    existing.set(existing.value.copyWith(value: state), notify: notify);
  }

  /// Forgets every controller.
  void clear() {
    for (final MapEntry<String, PaginationController> entry
        in _controllers.entries) {
      final VoidCallback? publisher = _publishers[entry.key];
      if (publisher != null) entry.value.removeListener(publisher);
      entry.value.dispose();
    }
    _controllers.clear();
    _publishers.clear();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
