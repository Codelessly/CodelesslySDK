import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';

import '../catalog/catalog_spec.dart';
import '../catalog/genui_catalog.dart';
import '../render/genui_theme.dart';
import 'events.dart';
import 'stream_parser.dart';

/// One problem in agent output: a message the processor rejected, or a
/// payload that failed the catalog schema.
@immutable
class GenUiIssue {
  const GenUiIssue({
    required this.code,
    required this.message,
    this.surfaceId,
    this.path,
  });

  final String code;
  final String message;
  final String? surfaceId;
  final String? path;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'surfaceId': ?surfaceId,
    'path': ?path,
  };

  @override
  String toString() =>
      '$code${surfaceId == null ? '' : ' [$surfaceId]'}'
      '${path == null ? '' : ' at $path'}: $message';
}

/// The GenUI renderer state of one chat: the A2UI message processor with the
/// Codelessly catalog, the surfaces it created, and the typed events the
/// user's interactions produce.
///
/// Messages are applied as they arrive. a2ui_core keeps one signal per
/// component and per data path, so an update rebuilds only the components
/// it touches; the rest of the tree, and the state of untouched widgets,
/// stays as it is.
class GenUiSession {
  GenUiSession({
    GenUiTheme theme = const GenUiTheme(),
    CatalogImplementation? catalog,
    this.validate = true,
  }) : catalog = catalog ?? genUiCatalog(theme: theme) {
    processor = MessageProcessor<ComponentImplementation>(
      catalogs: [this.catalog],
      defaultVersion: kGenUiProtocolVersion,
    );
    _subscriptions.add(processor.model.onSurfaceCreated.subscribe(_attach));
    _subscriptions.add(
      processor.model.onSurfaceDeleted.subscribe((id) {
        _detach(id);
        surfaces.value = [
          for (final s in surfaces.value)
            if (s.id != id) s,
        ];
      }),
    );
    _subscriptions.add(processor.model.onAction.subscribe(_onAction));
  }

  final CatalogImplementation catalog;

  /// Whether [apply] validates payloads against the catalog schema first.
  final bool validate;

  late final MessageProcessor<ComponentImplementation> processor;

  /// The live surfaces, in creation order.
  final ValueNotifier<List<SurfaceModel<ComponentImplementation>>> surfaces =
      ValueNotifier(const []);

  final StreamController<GenUiEvent> _events =
      StreamController<GenUiEvent>.broadcast();
  final List<Subscription> _subscriptions = [];
  final Map<String, List<Object>> _surfaceSubscriptions = {};

  /// Whether the processor is applying agent messages: data model changes
  /// during that time are the agent's, not the user's.
  bool _applyingAgentMessages = false;

  /// Actions, value changes and errors from every surface.
  Stream<GenUiEvent> get events => _events.stream;

  SurfaceModel<ComponentImplementation>? surface(String id) =>
      processor.model.getSurface(id);

  /// A copy of the data model of surface [id].
  Map<String, Object?> dataModelOf(String id) {
    final Object? value = surface(id)?.dataModel.get('/');
    return value is Map
        ? (jsonDecode(jsonEncode(value)) as Map<String, Object?>)
        : <String, Object?>{};
  }

  /// The `a2uiClientDataModel` transport metadata: the data model of every
  /// surface created with `sendDataModel`.
  Map<String, Object?>? clientDataModel() =>
      processor.getRendererDataModel(version: kGenUiProtocolVersion);

  /// Applies agent messages: one message, a list, or JSONL text. Returns the
  /// problems found; valid messages are applied even when others fail.
  List<GenUiIssue> apply(Object? payload) {
    final List<Object?> messages = switch (payload) {
      final String text => _parseText(text),
      final List list => list,
      _ => [payload],
    };
    final List<GenUiIssue> issues = [];
    for (final Object? message in messages) {
      issues.addAll(_applyOne(message));
    }
    return issues;
  }

  List<Object?> _parseText(String text) {
    final parser = A2uiJsonStreamParser();
    return parser.add(text);
  }

  /// Drops `returnType` from `calc` calls. calc returns whatever its
  /// formula computes, and the v0.9 validator only accepts a call whose
  /// returnType equals the function's declared one ("any").
  static Object? normalize(Object? value) => switch (value) {
    final Map m => {
      for (final e in m.entries)
        if (!(m['call'] == 'calc' && e.key == 'returnType'))
          '${e.key}': normalize(e.value),
    },
    final List l => [for (final v in l) normalize(v)],
    _ => value,
  };

  List<GenUiIssue> _applyOne(Object? message) {
    message = normalize(message);
    _applyingAgentMessages = true;
    try {
      List<GenUiIssue> issues = _process(message);
      // A component that fails its schema rejects the whole
      // updateComponents. Show the rest: replace each failing component
      // with a placeholder under the same id and apply again. The issues
      // are still reported, so the agent can send a fix.
      final List<GenUiIssue> reported = [...issues];
      for (int round = 0; round < 4 && issues.isNotEmpty; round++) {
        final Object? patched = _patchInvalid(message, issues);
        if (patched == null) break;
        message = patched;
        issues = _process(message);
        reported.addAll(
          issues.where(
            (i) => !reported.any((r) => r.toString() == i.toString()),
          ),
        );
      }
      return reported;
    } on A2uiError catch (error) {
      return [GenUiIssue(code: error.code, message: error.message)];
    } catch (error) {
      return [GenUiIssue(code: 'INVALID_MESSAGE', message: '$error')];
    } finally {
      _applyingAgentMessages = false;
    }
  }

  List<GenUiIssue> _process(Object? message) => [
    for (final ErrorMessage e in processor.processMessagesWithErrors(message))
      GenUiIssue(
        code: e.error.code,
        message: e.error.message,
        surfaceId: e.error.surfaceId,
        path: e.error.path,
      ),
  ];

  static Object? _patchInvalid(Object? message, List<GenUiIssue> issues) {
    if (message is! Map || message['updateComponents'] is! Map) return null;
    final Map update = message['updateComponents'] as Map;
    final List components = [...(update['components'] as List? ?? const [])];
    bool changed = false;
    for (final GenUiIssue issue in issues) {
      final Match? m = RegExp(r'^/components/(\d+)')
          .firstMatch(issue.path ?? '');
      if (m == null) continue;
      final int index = int.parse(m.group(1)!);
      if (index >= components.length) continue;
      final Object? c = components[index];
      final Object? id = c is Map ? c['id'] : null;
      if (id is! String || (c as Map)['component'] == 'Text') continue;
      components[index] = {
        'id': id,
        'component': 'Text',
        'variant': 'caption',
        'text': '⚠ $id could not be shown',
      };
      changed = true;
    }
    if (!changed) return null;
    return {
      ...message,
      'updateComponents': {...update, 'components': components},
    };
  }

  /// Starts a streamed reply: feed it text as it arrives and each complete
  /// message is applied at once. [depth] is 0 for JSONL, 2 for the
  /// `{"messages": [...]}` render tool input.
  GenUiStreamFeed openStream({int depth = 0}) =>
      GenUiStreamFeed._(this, A2uiJsonStreamParser(depth: depth));

  /// Validates a complete reply against the catalog without applying it:
  /// JSON Schema per component, unique ids, one root, no dangling or
  /// circular references. Used for the agent's tool result, so it can fix
  /// its own output.
  List<GenUiIssue> check(List<Object?> messages) {
    final List<GenUiIssue> issues = [];
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [catalog],
      defaultVersion: kGenUiProtocolVersion,
    );
    try {
      for (final Object? raw in messages) {
        final Object? message = normalize(raw);
        try {
          for (final e in processor.processMessagesWithErrors(message)) {
            issues.add(
              GenUiIssue(
                code: e.error.code,
                message: e.error.message,
                surfaceId: e.error.surfaceId,
                path: e.error.path,
              ),
            );
          }
        } on A2uiError catch (error) {
          issues.add(GenUiIssue(code: error.code, message: error.message));
        }
      }
      issues.addAll(_checkGraph(processor));
      issues.addAll(_checkTypes(messages));
    } finally {
      processor.dispose();
    }
    return issues;
  }

  /// Components whose type is not in the catalog, which the processor
  /// leaves out without an error.
  List<GenUiIssue> _checkTypes(List<Object?> messages) => [
    for (final Object? m in messages)
      if (m is Map && m['updateComponents'] is Map)
        for (final Object? c
            in ((m['updateComponents'] as Map)['components'] as List?) ??
                const [])
          if (c is Map && !catalog.components.containsKey(c['component']))
            GenUiIssue(
              code: 'VALIDATION_FAILED',
              surfaceId: '${(m['updateComponents'] as Map)['surfaceId']}',
              path: '/components/${c['id']}',
              message:
                  'Unknown component "${c['component']}"; the catalog has '
                  '${catalog.components.keys.join(', ')}.',
            ),
  ];

  List<GenUiIssue> _checkGraph(MessageProcessor<ComponentImplementation> p) {
    final List<GenUiIssue> issues = [];
    for (final SurfaceModel<ComponentImplementation> s in p.model.allSurfaces) {
      final SurfaceComponentsModel components = s.componentsModel;
      if (!components.has(s.rootId)) {
        issues.add(
          GenUiIssue(
            code: 'VALIDATION_FAILED',
            surfaceId: s.id,
            message: 'No component has id "${s.rootId}"; nothing renders.',
          ),
        );
        continue;
      }
      for (final ComponentModel component in components.all) {
        for (final String ref in _refsOf(component.toJson())) {
          if (!components.has(ref)) {
            issues.add(
              GenUiIssue(
                code: 'VALIDATION_FAILED',
                surfaceId: s.id,
                path: '/components/${component.id}',
                message:
                    '${component.id} references "$ref", which is not a '
                    'component.',
              ),
            );
          }
        }
      }
    }
    return issues;
  }

  static Iterable<String> _refsOf(Map<String, dynamic> json) sync* {
    for (final String key in const [
      'child',
      'detail',
      'trigger',
      'content',
      'entryPointChild',
      'contentChild',
    ]) {
      if (json[key] is String) yield json[key] as String;
    }
    for (final String key in const ['children', 'controls', 'inlineControls']) {
      final Object? value = json[key];
      if (value is List) yield* value.whereType<String>();
      if (value is Map && value['componentId'] is String) {
        yield value['componentId'] as String;
      }
    }
    final Object? tabs = json['tabs'];
    if (tabs is List) {
      for (final Object? tab in tabs) {
        if (tab is Map && tab['child'] is String) yield tab['child'] as String;
      }
    }
  }

  void _attach(SurfaceModel<ComponentImplementation> surface) {
    final List<Object> subs = [];
    subs.add(
      surface.onError.subscribe((error) {
        _events.add(
          GenUiErrorEvent(
            surfaceId: surface.id,
            timestamp: DateTime.now(),
            dataModel: dataModelOf(surface.id),
            error: error,
          ),
        );
      }),
    );
    Object? last = jsonEncode(surface.dataModel.get('/'));
    final DataSubscription<Object?> data = surface.dataModel.subscribe<Object?>(
      '/',
      (value) {
        final String encoded = jsonEncode(value);
        if (encoded == last) return;
        final Object? before = last == null ? null : jsonDecode(last as String);
        last = encoded;
        if (_applyingAgentMessages) return;
        for (final (String path, Object? v) in _diff(before, value, '')) {
          _events.add(
            GenUiValueChanged(
              surfaceId: surface.id,
              timestamp: DateTime.now(),
              dataModel: dataModelOf(surface.id),
              path: path,
              value: v,
            ),
          );
        }
      },
    );
    subs.add(data);
    _surfaceSubscriptions[surface.id] = subs;
    surfaces.value = [...surfaces.value, surface];
  }

  void _detach(String id) {
    for (final Object sub in _surfaceSubscriptions.remove(id) ?? const []) {
      if (sub is Subscription) sub.unsubscribe();
      if (sub is DataSubscription) sub.unsubscribe();
    }
  }

  /// The leaf paths that differ between [a] and [b].
  static Iterable<(String, Object?)> _diff(
    Object? a,
    Object? b,
    String path,
  ) sync* {
    if (a is Map && b is Map) {
      for (final Object? key in {...a.keys, ...b.keys}) {
        final String k = '$key'.replaceAll('~', '~0').replaceAll('/', '~1');
        yield* _diff(a[key], b[key], '$path/$k');
      }
    } else if (jsonEncode(a) != jsonEncode(b)) {
      yield (path.isEmpty ? '/' : path, b);
    }
  }

  void _onAction(A2uiRendererAction action) {
    final SurfaceModel<ComponentImplementation>? s = surface(action.surfaceId);
    final String? type = s?.componentsModel.get(action.sourceComponentId)?.type;
    _events.add(
      GenUiActionEvent(
        surfaceId: action.surfaceId,
        timestamp: action.timestamp,
        dataModel: dataModelOf(action.surfaceId),
        name: action.name,
        sourceComponentId: action.sourceComponentId,
        sourceComponentType: type,
        interaction: classifyInteraction(type, action.name),
        context: Map<String, Object?>.from(action.context),
        action: action,
      ),
    );
  }

  void dispose() {
    for (final Subscription s in _subscriptions) {
      s.unsubscribe();
    }
    for (final String id in [..._surfaceSubscriptions.keys]) {
      _detach(id);
    }
    processor.dispose();
    surfaces.dispose();
    _events.close();
  }
}

/// An open streamed reply; see [GenUiSession.openStream].
class GenUiStreamFeed {
  GenUiStreamFeed._(this._session, this._parser);

  final GenUiSession _session;
  final A2uiJsonStreamParser _parser;
  final List<Map<String, Object?>> _messages = [];
  final List<GenUiIssue> _issues = [];

  /// The messages applied so far.
  List<Map<String, Object?>> get messages => List.unmodifiable(_messages);

  /// The problems found so far.
  List<GenUiIssue> get issues => List.unmodifiable(_issues);

  /// Adds streamed text; returns the messages it completed.
  List<Map<String, Object?>> add(String chunk) {
    final List<Map<String, Object?>> done = _parser.add(chunk);
    for (final Map<String, Object?> message in done) {
      _messages.add(message);
      _issues.addAll(_session.apply(message));
    }
    return done;
  }
}
