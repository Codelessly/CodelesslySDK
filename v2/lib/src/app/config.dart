import 'package:codelessly_api/codelessly_api.dart' show PublishSource;
import 'package:flutter/foundation.dart';

import '../runtime/contracts.dart';
import 'runtime.dart';

/// How a [Codelessly] instance runs: which project and publish it shows, and
/// the runtime plugins (expressions, actions, services) its layouts use.
@immutable
class CodelesslyConfig {
  const CodelesslyConfig({
    this.projectId,
    this.slug,
    this.authToken,
    this.publishSource = PublishSource.publish,
    this.preload = false,
    this.expressions = const NoopExpressionEngine(),
    this.actions = const NoopActionRunner(),
    this.services = const NoServices(),
    this.useHostTheme = false,
    this.maxTextScaleFactor = 1,
    this.fontTimeout = const Duration(seconds: 2),
    this.debugLog = false,
  }) : assert(maxTextScaleFactor >= 1);

  /// The published project.
  final String? projectId;

  /// The project's public slug: the publish comes as one bundle.
  final String? slug;

  /// The SDK token of the project, for loaders that authenticate.
  final String? authToken;

  /// Which publish to show: the published layouts, the editor's preview, or
  /// a template.
  final PublishSource publishSource;

  /// Whether [Codelessly.initialize] loads every layout up front (else each
  /// loads when first shown).
  final bool preload;

  /// Evaluates bindings and formulas. The default evaluates nothing.
  final ExpressionEngine expressions;

  /// Runs reactions (taps, loads...). The default runs nothing;
  /// [NavigationActionRunner] runs navigation and links only.
  final ActionRunner actions;

  /// Data, APIs, links and the rest of the app's services.
  final CodelesslyServices services;

  /// Whether layouts render with the app's [Theme] instead of their own
  /// (from the project's theme tokens).
  final bool useHostTheme;

  /// The largest text scale factor layouts follow from the platform's text
  /// size setting. Layouts are designed at fixed sizes: 1 ignores it.
  final double maxTextScaleFactor;

  /// How long a layout waits for its fonts before it shows (they apply when
  /// they arrive).
  final Duration fontTimeout;

  final bool debugLog;

  /// Whether this shows the editor's preview.
  bool get isPreview => publishSource == PublishSource.preview;

  /// The project's key: its slug, else its id.
  String get uniqueId => slug ?? projectId ?? '';

  CodelesslyConfig copyWith({
    String? projectId,
    String? slug,
    String? authToken,
    PublishSource? publishSource,
    bool? preload,
    ExpressionEngine? expressions,
    ActionRunner? actions,
    CodelesslyServices? services,
    bool? useHostTheme,
    double? maxTextScaleFactor,
    Duration? fontTimeout,
    bool? debugLog,
  }) =>
      CodelesslyConfig(
        projectId: projectId ?? this.projectId,
        slug: slug ?? this.slug,
        authToken: authToken ?? this.authToken,
        publishSource: publishSource ?? this.publishSource,
        preload: preload ?? this.preload,
        expressions: expressions ?? this.expressions,
        actions: actions ?? this.actions,
        services: services ?? this.services,
        useHostTheme: useHostTheme ?? this.useHostTheme,
        maxTextScaleFactor: maxTextScaleFactor ?? this.maxTextScaleFactor,
        fontTimeout: fontTimeout ?? this.fontTimeout,
        debugLog: debugLog ?? this.debugLog,
      );
}

/// Where a [Codelessly] instance is in loading its publish.
sealed class CStatus {
  const CStatus();
}

/// Not initialized.
final class CEmpty extends CStatus {
  const CEmpty();
}

/// Loading the publish model.
final class CLoading extends CStatus {
  const CLoading();
}

/// The publish model is loaded (layouts load on their own).
final class CLoaded extends CStatus {
  const CLoaded();
}

/// Loading failed.
final class CError extends CStatus {
  const CError(this.message, [this.error]);

  final String message;
  final Object? error;

  @override
  String toString() => message;
}
