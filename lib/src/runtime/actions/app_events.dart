// The app's event bus, as actions reach it: an emitEvent action fires an app
// event on the bus of the Codelessly instance whose services it runs with
// (Codelessly.emit is the same bus, for the host app).
import 'package:flutter/foundation.dart';

/// One app event: a [name] and its [props], fired at [at].
@immutable
class AppEvent {
  const AppEvent(this.name, {this.props = const {}, required this.at});

  final String name;
  final Map<String, Object?> props;
  final DateTime at;

  /// `${event}` in automations: `{"name", "props", "at"}` (ms since epoch).
  Map<String, Object?> toJson() => {'name': name, 'props': props, 'at': at.millisecondsSinceEpoch};

  @override
  String toString() => 'AppEvent($name, $props)';
}

/// Where app events go: the Codelessly instance's automations and the host's
/// listeners.
abstract interface class AppEventBus {
  /// Fires app event [name] with [props].
  void emit(String name, [Map<String, Object?> props = const {}]);

  static final Expando<AppEventBus> _buses = Expando('codelessly app events');

  /// The bus of the instance whose services are [services].
  static AppEventBus? of(Object services) => _buses[services];

  /// Makes [bus] the bus of actions running with [services].
  static void register(Object services, AppEventBus? bus) => _buses[services] = bus;
}
