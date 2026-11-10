import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../functions/action_chain.dart';
import 'script_runner.dart';

/// The [ScriptHost] of a running layout: a script reads and writes its
/// variables, reads its inputs and calls its actions.
class FlutterScriptHost implements ScriptHost {
  /// The context the script was started from.
  final BuildContext context;

  /// Creates a [FlutterScriptHost].
  FlutterScriptHost(this.context);

  BuildContext get _context => ActionChain.contextFor(context) ?? context;

  CodelesslyContext get _codelessly => _context.read<CodelesslyContext>();

  @override
  Map<String, Object?> variables() {
    final ScopedValues scope = ActionChain.scopedValuesOf(_context);
    final Map<String, Object?> out = {};
    for (final Observable<VariableData> v in _codelessly.variables.values) {
      final VariableData data = v.value;
      if (data.isFunction) continue;
      // Read through the formula engine, so computed variables have their
      // values.
      out[data.name] =
          PropertyValueDelegate.getVariableValueFromPath<Object>(
            data.name.wrapWithVariableSyntax(),
            scopedValues: scope,
          ) ??
          data.getValue();
    }
    return out;
  }

  @override
  Map<String, Object?> nodeValues() {
    final Map<String, Object?> out = {};
    for (final MapEntry<String, Observable<List<ValueModel>>> entry
        in _codelessly.nodeValues.entries) {
      final ValueModel? value = entry.value.value
          .where((v) => v.name == 'value' || v.name == 'inputValue')
          .firstOrNull;
      if (value != null) out[entry.key] = value.value;
    }
    return out;
  }

  @override
  void setVariable(String name, Object? value) {
    final Observable<VariableData>? notifier = _codelessly.findVariable(
      name: name,
    );
    if (notifier == null) {
      throw ScriptHostError('There is no variable named "$name".');
    }
    final VariableData variable = notifier.value;
    if (variable.isComputed) {
      throw ScriptHostError(
        '"$name" is computed from a formula and can\'t be set.',
      );
    }
    notifier.value = variable.copyWith(
      value: _typed(variable.type, value, name),
    );
  }

  /// [value] as the [type] a variable holds.
  static Object? _typed(VariableType type, Object? value, String name) {
    Never wrong(String expected) => throw ScriptHostError(
      '"$name" holds $expected, so it can\'t be set to ${jsonEncode(value)}.',
      'TypeError',
    );
    if (value == null) return null;
    switch (type) {
      case VariableType.integer:
        if (value is num && value.isFinite) return value.round();
        if (value is String && num.tryParse(value) != null)
          return num.parse(value).round();
        wrong('a whole number');
      case VariableType.decimal:
        if (value is num) return value.toDouble();
        if (value is String && num.tryParse(value) != null)
          return num.parse(value).toDouble();
        wrong('a number');
      case VariableType.boolean:
        if (value is bool) return value;
        if (value == 'true' || value == 'false') return value == 'true';
        wrong('true or false');
      case VariableType.text:
      case VariableType.choice:
      case VariableType.image:
        return value is String ? value : jsonEncode(value);
      case VariableType.list:
        if (value is List) return value;
        wrong('a list');
      case VariableType.map:
        if (value is Map) return value;
        wrong('an object');
      case VariableType.color:
        if (value is String) return ColorRGBA.fromHex(value);
        if (value is Map) return ColorRGBA.fromJson(value);
        wrong('a color');
    }
  }

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    Object? arg(int i) => i < args.length ? args[i] : null;
    switch (name) {
      case 'navigate':
        final String target = '${arg(0)}';
        final String? canvasId = _canvasIdOf(target);
        if (canvasId == null)
          throw ScriptHostError('There is no screen named "$target".');
        final Object? params = arg(1);
        await FunctionsRepository.navigate(
          _context,
          NavigationAction(
            destinationId: canvasId,
            params: params is Map ? params.cast<String, dynamic>() : const {},
          ),
          literalParams: true,
        );
        return null;
      case 'back':
        final Object? result = arg(0);
        await FunctionsRepository.navigate(
          _context,
          NavigationAction(
            navigationType: NavigationType.pop,
            params: result is Map ? result.cast<String, dynamic>() : const {},
          ),
          literalParams: true,
        );
        return null;
      case 'callApi':
        return _callApi('${arg(0)}', arg(1));
      case 'runAction':
        final Object? json = arg(0);
        if (json is! Map)
          throw const ScriptHostError(
            'app.runAction() needs an action object.',
          );
        final ActionModel action;
        try {
          action = ActionModel.fromJson(json);
        } on Object catch (e) {
          throw ScriptHostError('That isn\'t an action: $e');
        }
        if (action is RunScriptAction) {
          throw const ScriptHostError(
            'Scripts call other scripts with script.name(...), not app.runAction().',
          );
        }
        return _runActions([action]);
      case 'toast':
        return _runActions([ShowToastAction(message: '${arg(0)}')]);
      case 'delay':
        final num ms = arg(0) is num ? arg(0) as num : 0;
        await Future<void>.delayed(
          Duration(milliseconds: ms.clamp(0, 60000).toInt()),
        );
        return null;
      case 'cloudData':
        final Object? json = arg(0);
        if (json is! Map)
          throw const ScriptHostError(
            'app.cloudData() needs a request object.',
          );
        return _runActions([
          CloudDataAction.fromJson({...json, 'type': 'cloudData'}),
        ]);
    }
    throw ScriptHostError('Unknown host call "$name".');
  }

  /// Runs [actions] in a chain nested in the current one and returns the
  /// `${result}` they left.
  Future<Object?> _runActions(List<ActionModel> actions) async {
    Object? result;
    await ActionChain.run(() async {
      await FunctionsRepository.runActions(_context, actions);
      result = ActionChain.current?.result;
    });
    return result;
  }

  Future<Object?> _callApi(String nameOrId, Object? inputs) async {
    final SDKPublishModel? model = _context
        .read<Codelessly>()
        .dataManager
        .publishModel;
    final HttpApiData? api =
        model?.apis[nameOrId] ??
        model?.apis.values.where((a) => a.name == nameOrId).firstOrNull;
    if (api == null)
      throw ScriptHostError('There is no API named "$nameOrId".');
    final http.Response response =
        await FunctionsRepository.makeApiRequestFromAction(
          ApiCallAction(
            apiId: api.id,
            parameters: {
              if (inputs is Map)
                for (final MapEntry e in inputs.entries)
                  '${e.key}': e.value is String
                      ? e.value as String
                      : jsonEncode(e.value),
            },
          ),
          _context,
        );
    Object? body = response.body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      // Not JSON: the text.
    }
    return {
      'status': response.statusCode,
      'ok': response.statusCode >= 200 && response.statusCode < 300,
      'body': body,
      'headers': response.headers,
    };
  }

  /// The id of the screen [target] names: a canvas id, or a canvas's name.
  String? _canvasIdOf(String target) {
    final SDKPublishModel? model = _context
        .read<Codelessly>()
        .dataManager
        .publishModel;
    if (model == null) return target;
    for (final SDKPublishLayout layout in model.layouts.values) {
      if (layout.canvases.containsKey(target)) return target;
    }
    for (final SDKPublishLayout layout in model.layouts.values) {
      for (final MapEntry<String, Map<String, BaseNode>> canvas
          in layout.canvases.entries) {
        if (canvas.value[canvas.key]?.name == target) return canvas.key;
      }
    }
    // Layouts load lazily: let the navigation resolve an unknown id.
    return target;
  }
}
