import 'package:codelessly_api/codelessly_api.dart' show Catalog, PublishSource, standardCatalog;
import 'package:flutter/foundation.dart';

import '../render/recipe.dart' show WidgetRecipe;
import '../runtime/contracts.dart';
import '../runtime/actions/context.dart' show AppFunction;
import '../runtime/actions/runner.dart' show CoreActions;
import '../features/first_party.dart' show CodelesslyActions;
import '../runtime/expressions/engine.dart' show Expressions;
import 'runtime.dart';

/// How a [Codelessly] instance runs: which project and publish it shows, and
/// the runtime plugins (expressions, actions, services) its layouts use.
///
/// One of [slug], [authToken] or [projectId] names the project, unless the
/// instance is given a loader ([Codelessly.asset], [Codelessly.fromBundle]):
///
/// ```dart
/// const CodelesslyConfig(slug: 'my-project');
///
/// CodelesslyConfig(
///   slug: 'my-project',
///   preload: true,
///   functions: {
///     'addToCart': (context, params) => cart.add(params['productId']),
///   },
/// );
/// ```
@immutable
class CodelesslyConfig {
  const CodelesslyConfig({
    this.projectId,
    this.slug,
    this.authToken,
    this.publishSource = PublishSource.publish,
    this.preload = false,
    this.liveUpdates = true,
    this.expressions = const Expressions(),
    this.actions = const CodelesslyActions(),
    this.services,
    this.functions = const {},
    this.recipes = const {},
    this.useHostTheme = false,
    this.maxTextScaleFactor = 1,
    this.fontTimeout = const Duration(seconds: 2),
    this.debugLog = false,
  }) : assert(maxTextScaleFactor >= 1);

  /// The published project's id. Read from Firestore
  /// (`codelesslyOnFirebase`), without authenticating unless [authToken] is
  /// set too.
  final String? projectId;

  /// The project's public slug: the publish comes as one bundle, over
  /// HTTP, without Firebase.
  final String? slug;

  /// The SDK token of the project, for loaders that authenticate:
  /// `codelesslyWithToken` and `codelesslyOnFirebase` in
  /// `package:codelessly_sdk/firebase.dart`. A token alone, on an instance
  /// without such a loader, fails to load with a [PublishLoadException]
  /// that says so.
  final String? authToken;

  /// Which publish to show: the published layouts, the editor's preview, or
  /// a template.
  final PublishSource publishSource;

  /// Whether [Codelessly.initialize] loads every layout up front (else each
  /// loads when first shown).
  final bool preload;

  /// Whether a loader that watches the publish ([LivePublishLoader], as the
  /// Firestore one does) brings each new publish (or preview save) to the
  /// running app: republished layouts load again when shown.
  final bool liveUpdates;

  /// Evaluates bindings, conditions and formulas: the runtime's
  /// [Expressions] (variables and conditions per screen, `${...}` text). A
  /// [NoopExpressionEngine] shows layouts as designed.
  final ExpressionEngine expressions;

  /// Runs reactions (taps, loads, inputs...): [CodelesslyActions], every
  /// action type. [NavigationActionRunner] runs navigation and links only,
  /// [NoopActionRunner] nothing.
  final ActionRunner actions;

  /// Data, APIs, auth, storage, links and the rest of the app's services;
  /// null: [Services] with their defaults (HTTP APIs, memory storage and
  /// data, signed out).
  final CodelesslyServices? services;

  /// The functions call function actions call, by name.
  final Map<String, AppFunction> functions;

  /// The app's own widget recipes by node type, over the built-in ones
  /// ([NodeTree.recipes]): how a layout shows a node type the app defines.
  final Map<String, WidgetRecipe> recipes;

  /// Whether layouts render with the app's [Theme] instead of their own
  /// (from the project's theme tokens).
  final bool useHostTheme;

  /// The largest text scale factor layouts follow from the platform's text
  /// size setting. Layouts are designed at fixed sizes: 1 ignores it.
  final double maxTextScaleFactor;

  /// How long a layout waits for its fonts before it shows (they apply when
  /// they arrive).
  final Duration fontTimeout;

  /// Reserved: the SDK doesn't read it yet. Errors go to the services'
  /// analytics ([Services.analytics]; printed in debug builds).
  final bool debugLog;

  /// What layouts are decoded with: [Catalog.core] and the catalogs of the
  /// features [actions] installs ([CoreActions.catalog]: the standard
  /// catalog's types for [CodelesslyActions]); [standardCatalog] for a runner
  /// that isn't a [CoreActions].
  Catalog get catalog => switch (actions) {
        final CoreActions a => a.catalog,
        _ => standardCatalog,
      };

  /// The recipes layouts build their nodes with beyond the built-in ones:
  /// the installed features' ([CodelesslyFeature.recipes]: the media
  /// feature's players), then the app's own [recipes] over them.
  Map<String, WidgetRecipe> get allRecipes => switch (actions) {
        final CoreActions a when a.recipes.isNotEmpty => {...a.recipes, ...recipes},
        _ => recipes,
      };

  /// Whether this shows the editor's preview.
  bool get isPreview => publishSource == PublishSource.preview;

  /// The project's key (its cache entries'): its slug, else its id, else
  /// its project token.
  String get uniqueId => slug ?? projectId ?? authToken ?? '';

  CodelesslyConfig copyWith({
    String? projectId,
    String? slug,
    String? authToken,
    PublishSource? publishSource,
    bool? preload,
    bool? liveUpdates,
    ExpressionEngine? expressions,
    ActionRunner? actions,
    CodelesslyServices? services,
    Map<String, AppFunction>? functions,
    Map<String, WidgetRecipe>? recipes,
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
        liveUpdates: liveUpdates ?? this.liveUpdates,
        expressions: expressions ?? this.expressions,
        actions: actions ?? this.actions,
        services: services ?? this.services,
        functions: functions ?? this.functions,
        recipes: recipes ?? this.recipes,
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
