// RuntimeActionContext: the core action context with the first-party
// features' fields as named parameters, as apps and the app shell have always
// built it. The core (runtime/actions/context.dart) carries them as opaque
// extensions; each feature reads its own.
import 'package:codelessly_api/codelessly_api.dart' show AuthOperation;

import '../runtime/actions/context.dart';
import '../runtime/contracts.dart';
import 'auth/auth.dart' show AuthValuesRefresh;
import 'data/app_data_sources.dart';

/// The [ActionContext] (and [ActionHost]) of a screen: [CoreActionContext]
/// plus what the first-party features' handlers read.
class RuntimeActionContext extends CoreActionContext {
  RuntimeActionContext({
    required super.scope,
    super.expressions,
    super.services,
    super.ui,
    super.functions,
    super.tree,
    super.nodeValues,
    super.onError,
    super.onActionErrorEvent,
    this.refreshAuthValues,
    this.appData,
    super.declareMissing,
    super.paywall,
    super.openPaywall,
    super.presentPaywall,
    super.scripts,
    List<Object> extensions = const [],
    super.disposers,
    super.failed,
  })  : _extensions = extensions,
        super(extensions: [
          ...extensions,
          if (refreshAuthValues != null) AuthValuesRefresh(refreshAuthValues),
          ?appData,
        ]);

  /// The extensions it was given, without those its fields make.
  final List<Object> _extensions;

  /// Synchronizes host-owned auth values after a completed native operation,
  /// before the next authored action reads them. Expression reads stay pure.
  final void Function(AuthOperation operation)? refreshAuthValues;

  /// The app's shared live data (`loadCloudData` with `scope: app`); null:
  /// such loads are the screen's.
  final AppDataSources? appData;

  @override
  RuntimeActionContext withScope(ValueScope scope) => copy(scope);

  @override
  RuntimeActionContext withoutActionErrorEvents() => copy(scope, suppressErrorEvents: true);

  @override
  RuntimeActionContext copy(ValueScope scope, {bool suppressErrorEvents = false}) => RuntimeActionContext(
        scope: scope,
        expressions: expressions,
        services: services,
        ui: ui,
        functions: functions,
        tree: tree,
        nodeValues: nodeValues,
        onError: onError,
        onActionErrorEvent: suppressErrorEvents ? null : onActionErrorEvent,
        refreshAuthValues: refreshAuthValues,
        appData: appData,
        declareMissing: declareMissing,
        paywall: paywall,
        openPaywall: openPaywall,
        presentPaywall: presentPaywall,
        scripts: scripts,
        extensions: _extensions,
        disposers: disposers,
        failed: failed,
      );
}
