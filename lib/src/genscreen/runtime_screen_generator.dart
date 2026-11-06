// Screens generated at runtime from a one-line prompt and a DESIGN.md kit:
// a Codelessly app calls the `generateScreen` function (a Call function
// action with params {prompt, kit}) and navigates to the result. The plan
// comes from a [ScreenPlanSource] (a host endpoint, so no API key ships in
// the app, or the Claude API directly for trusted builds); it is validated
// (one fix round), compiled with the kit's tokens and cached per prompt and
// kit fingerprint, so asking again opens the same screen instantly.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/genscreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';

/// One model turn of a plan conversation.
typedef PlanTurn = ({String role, String text});

/// Where generated plans come from: a model behind an endpoint the app
/// trusts.
abstract interface class ScreenPlanSource {
  /// The model's answer to [turns] under [system].
  Future<String> complete({required String system, required List<PlanTurn> turns});
}

/// Asks a host endpoint, which holds the API key and calls the model:
/// `POST {"system", "messages": [{"role", "content"}]}` answered with
/// `{"text": "<the model's answer>"}`.
class HttpScreenPlanSource implements ScreenPlanSource {
  /// The endpoint.
  final Uri endpoint;

  /// Extra headers (an app token).
  final Map<String, String> headers;

  final http.Client _client;

  /// Creates an [HttpScreenPlanSource].
  HttpScreenPlanSource(this.endpoint, {this.headers = const {}, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<String> complete({required String system, required List<PlanTurn> turns}) async {
    final http.Response response = await _client.post(
      endpoint,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'system': system,
        'messages': [for (final PlanTurn t in turns) {'role': t.role, 'content': t.text}],
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Screen generator endpoint answered ${response.statusCode}.');
    }
    final Object? json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is Map && json['text'] is String) return json['text'] as String;
    throw const FormatException('The endpoint answer has no "text".');
  }
}

/// Calls the Claude Messages API directly. Only for builds that may hold
/// a key (tools, trusted kiosks); ship [HttpScreenPlanSource] in apps.
class ClaudeScreenPlanSource implements ScreenPlanSource {
  /// The API key.
  final String apiKey;

  /// The model.
  final String model;

  final http.Client _client;

  /// Creates a [ClaudeScreenPlanSource].
  ClaudeScreenPlanSource(this.apiKey, {this.model = 'claude-opus-5-5', http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<String> complete({required String system, required List<PlanTurn> turns}) async {
    final http.Response response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2026-10-21',
        'anthropic-beta': 'server-side-fallback-2026-07-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 16000,
        'thinking': {'type': 'adaptive'},
        'output_config': {'effort': 'medium'},
        'fallbacks': 'default',
        'system': [
          {'type': 'text', 'text': system, 'cache_control': {'type': 'ephemeral'}},
        ],
        'messages': [for (final PlanTurn t in turns) {'role': t.role, 'content': t.text}],
      }),
    );
    final Map<String, dynamic> json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError('Claude API ${response.statusCode}: ${json['error']}');
    }
    return [
      for (final dynamic b in json['content'] as List)
        if (b is Map && b['type'] == 'text') b['text'] as String,
    ].join();
  }
}

/// Generated screens kept by cache key ([screenCacheKey]): in memory, and
/// through [load]/[save] wherever the host keeps them (local storage).
class GeneratedScreenCache {
  final Map<String, Map<String, dynamic>> _plans = {};

  /// Reads a plan saved earlier, or null.
  final FutureOr<String?> Function(String key)? load;

  /// Saves a plan.
  final FutureOr<void> Function(String key, String plan)? save;

  /// Creates a [GeneratedScreenCache].
  GeneratedScreenCache({this.load, this.save});

  /// The cached plan for [key], or null.
  Future<Map<String, dynamic>?> get(String key) async {
    final Map<String, dynamic>? hit = _plans[key];
    if (hit != null) return hit;
    final String? stored = await load?.call(key);
    if (stored == null) return null;
    return _plans[key] = jsonDecode(stored) as Map<String, dynamic>;
  }

  /// Keeps [plan] under [key].
  Future<void> put(String key, Map<String, dynamic> plan) async {
    _plans[key] = plan;
    await save?.call(key, jsonEncode(plan));
  }
}

/// Generates screens on demand and opens them.
class RuntimeScreenGenerator {
  /// The model behind the generator.
  final ScreenPlanSource source;

  /// Kits by name: DESIGN.md text. The first is the default kit.
  final Map<String, String> kits;

  /// Where generated plans are kept.
  final GeneratedScreenCache cache;

  /// Fix rounds after the first plan when it doesn't validate.
  final int fixRounds;

  final Map<String, DesignKit> _parsed = {};
  final Map<String, Future<CompiledScreen>> _pending = {};

  /// Creates a [RuntimeScreenGenerator].
  RuntimeScreenGenerator({
    required this.source,
    required this.kits,
    GeneratedScreenCache? cache,
    this.fixRounds = 1,
  }) : cache = cache ?? GeneratedScreenCache(),
       assert(kits.isNotEmpty, 'Give at least one DESIGN.md kit.');

  /// The kit called [name], or the default one.
  DesignKit kit([String? name]) {
    final String key = name != null && kits.containsKey(name) ? name : kits.keys.first;
    return _parsed[key] ??= const DesignMdParser().parse(kits[key]!).kit;
  }

  /// The screen for [prompt] in [kitName]: from the cache, or generated.
  /// Concurrent requests for the same screen share one generation.
  Future<CompiledScreen> generate(String prompt, {String? kitName}) {
    final DesignKit designKit = kit(kitName);
    final String key = screenCacheKey(prompt, designKit);
    // A block body: returning the removed future would make whenComplete
    // wait for itself.
    return _pending[key] ??= _generate(prompt, designKit, key).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<CompiledScreen> _generate(String prompt, DesignKit designKit, String key) async {
    final Map<String, dynamic>? cached = await cache.get(key);
    if (cached != null) return ScreenCompiler(designKit).compile(cached);
    final ScreenPrompt prompts = ScreenPrompt(designKit);
    final String system = prompts.system();
    final List<PlanTurn> turns = [(role: 'user', text: prompts.user(prompt))];
    Object? lastError;
    for (int round = 0; round <= fixRounds; round++) {
      final String answer = await source.complete(system: system, turns: turns);
      turns.add((role: 'assistant', text: answer));
      List<PlanIssue> errors;
      Map<String, dynamic>? plan;
      try {
        plan = extractPlanJson(answer);
        errors = ScreenPlanValidator(designKit)
            .validate(plan)
            .where((PlanIssue i) => i.severity == PlanSeverity.error)
            .toList();
      } on FormatException catch (e) {
        errors = [PlanIssue(r'$', PlanSeverity.error, 'Not valid JSON: ${e.message}')];
      }
      if (errors.isEmpty && plan != null) {
        try {
          final CompiledScreen screen = ScreenCompiler(designKit).compile(plan);
          await cache.put(key, plan);
          return screen;
        } on Object catch (e) {
          errors = [PlanIssue(r'$', PlanSeverity.error, 'The plan could not be built: $e')];
        }
      }
      lastError = errors.join('; ');
      turns.add((role: 'user', text: prompts.fix(issues: errors)));
    }
    throw StateError('No valid screen for "$prompt": $lastError');
  }

  /// The `generateScreen` app function: params `prompt` (required) and
  /// `kit` (a name in [kits]). Opens the screen as a new route at once,
  /// showing a loading state until it is ready.
  CodelesslyFunction<void> get function => (BuildContext context, CodelesslyContext parent, Map<String, dynamic> params) {
    final String prompt = '${params['prompt'] ?? ''}'.trim();
    if (prompt.isEmpty) return null;
    final String? kitName = params['kit'] as String?;
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/generated/${Uri.encodeComponent(prompt)}'),
        builder: (_) => GeneratedScreenPage(
          generator: this,
          prompt: prompt,
          kitName: kitName,
          functions: parent.functions,
        ),
      ),
    );
  };

  /// Makes `generateScreen` callable from [context]'s screens.
  void register(CodelesslyContext context) => context.functions['generateScreen'] = function;
}

/// A route that generates (or reads from the cache) and shows one screen.
class GeneratedScreenPage extends StatefulWidget {
  /// The generator.
  final RuntimeScreenGenerator generator;

  /// The request.
  final String prompt;

  /// The kit name, or null for the default kit.
  final String? kitName;

  /// App functions the generated screen may call (`generateScreen` itself,
  /// so generated screens can open more).
  final Map<String, CodelesslyFunction> functions;

  /// Creates a [GeneratedScreenPage].
  const GeneratedScreenPage({
    super.key,
    required this.generator,
    required this.prompt,
    this.kitName,
    this.functions = const {},
  });

  @override
  State<GeneratedScreenPage> createState() => _GeneratedScreenPageState();
}

class _GeneratedScreenPageState extends State<GeneratedScreenPage> {
  late Future<CompiledScreen> _screen = widget.generator.generate(widget.prompt, kitName: widget.kitName);

  @override
  Widget build(BuildContext context) => FutureBuilder<CompiledScreen>(
    future: _screen,
    builder: (BuildContext context, AsyncSnapshot<CompiledScreen> snapshot) {
      final DesignKit kit = widget.generator.kit(widget.kitName);
      final Color background = _color(kit.color('background'));
      if (snapshot.hasError) {
        return Scaffold(
          backgroundColor: background,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Couldn\'t make "${widget.prompt}".', style: TextStyle(color: _color(kit.color('onSurface')))),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _screen = widget.generator.generate(widget.prompt, kitName: widget.kitName)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      final CompiledScreen? screen = snapshot.data;
      if (screen == null) {
        return Scaffold(
          backgroundColor: background,
          body: Center(child: CircularProgressIndicator(color: _color(kit.color('primary')))),
        );
      }
      return Scaffold(
        backgroundColor: background,
        body: GeneratedScreenView(screen: screen, functions: widget.functions),
      );
    },
  );

  static Color _color(KitColor? c) =>
      c == null ? Colors.black : Color.fromARGB((c.opacity * 255).round(), c.r, c.g, c.b);
}

/// Renders a [CompiledScreen] with its variables, outside a published
/// layout: its actions (set variable, navigate back, toast, speak, call
/// function...) run as in any Codelessly screen.
class GeneratedScreenView extends StatefulWidget {
  /// The screen.
  final CompiledScreen screen;

  /// App functions its Call function actions reach.
  final Map<String, CodelesslyFunction> functions;

  /// Creates a [GeneratedScreenView].
  const GeneratedScreenView({super.key, required this.screen, this.functions = const {}});

  @override
  State<GeneratedScreenView> createState() => _GeneratedScreenViewState();
}

class _GeneratedScreenViewState extends State<GeneratedScreenView> {
  late final NodeRegistry _registry;
  late final PassiveNodeTransformerManager _manager;
  late final CodelesslyContext _context;
  late final BaseNode _root;

  @override
  void initState() {
    super.initState();
    final Map<String, Map<String, dynamic>> json = widget.screen.toLayoutNodes(canvasId: 'generated');
    final Map<String, BaseNode> nodes = {
      for (final MapEntry<String, Map<String, dynamic>> e in json.entries) e.key: NodeJsonConverter().fromJson(e.value)!,
    };
    for (final MapEntry<String, Map<String, dynamic>> e in json.entries) {
      nodes[e.key]!.parentID = e.value['parentID'] as String;
    }
    _root = nodes['generated']!;
    _registry = NodeRegistry()..setNodes(nodes);
    _manager = PassiveNodeTransformerManager(
      _registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox.shrink(),
    );
    _context = CodelesslyContext.empty()
      ..functions.addAll(widget.functions)
      ..variables.addAll({
        for (final Map<String, dynamic> v in widget.screen.variables)
          'var_${v['name']}': Observable(
            VariableData(
              id: 'var_${v['name']}',
              name: '${v['name']}',
              type: VariableType.values.firstWhere(
                (VariableType t) => t.name == v['type'],
                orElse: () => VariableType.text,
              ),
              value: v['value'],
            ),
          ),
      });
  }

  @override
  void dispose() {
    _context.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<CodelesslyContext>.value(
    value: _context,
    child: Builder(
      builder: (BuildContext context) => _manager.buildWidgetFromNode(
        _root,
        context,
        settings: const WidgetBuildSettings(debugLabel: 'generated screen'),
      ),
    ),
  );
}
