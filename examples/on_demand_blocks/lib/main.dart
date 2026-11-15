import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';

const requests = <(String, String)>[
  (
    'PollResults',
    'Show the results of a poll: Coffee 42%, Tea 35%, Water 23%, 200 votes. Make the shares clear at a glance.',
  ),
  (
    'MusicPlayer',
    'Show a compact music player for Night Drive by The Midnight, playing at 1:42 of 4:18, with play/pause and progress.',
  ),
  (
    'BoardingPass',
    'Show a boarding pass for Maya Chen, flight CL 204 from SFO to JFK, gate B12, seat 14A, boarding 08:35.',
  ),
];

final sdkRoot = Directory('../..').absolute;
final cardsRoot = Directory('${sdkRoot.path}/design_systems/cards');

Future<DesignSystem> loadCards() => DesignSystem.load((ref) async {
  final file = File('${cardsRoot.path}/$ref');
  return file.existsSync() ? file.readAsString() : null;
});

/// One Messages API request. The key stays in the process environment.
Future<String> ask(
  String model,
  String system,
  String user, {
  int maxTokens = 6000,
}) async {
  final key = Platform.environment['ANTHROPIC_API_KEY'];
  if (key == null || key.isEmpty)
    throw StateError('ANTHROPIC_API_KEY is not set.');
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('https://api.anthropic.com/v1/messages'),
    );
    request.headers.set('x-api-key', key);
    request.headers.set('anthropic-version', '2023-06-01');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200)
      throw StateError('Messages API ${response.statusCode}: $body');
    final value = jsonDecode(body) as Map<String, dynamic>;
    return (value['content'] as List)
        .where((part) => part['type'] == 'text')
        .map((part) => part['text'] as String)
        .join();
  } finally {
    client.close();
  }
}

/// Generate the exact system brief used by showcase/tool/design_block.py.
Future<String> designerBrief(String name) async {
  final out = await Directory.systemTemp.createTemp('on-demand-brief-');
  try {
    final result = await Process.run('python3', [
      'examples/showcase/tool/design_block.py',
      'brief',
      '--name',
      name,
      '--out',
      out.path,
    ], workingDirectory: sdkRoot.path);
    if (result.exitCode != 0)
      throw StateError('brief failed: ${result.stderr} ${result.stdout}');
    return await File('${out.path}/brief.txt').readAsString();
  } finally {
    await out.delete(recursive: true);
  }
}

Map<String, dynamic>? jsonFence(String answer) {
  final match = RegExp(r'```json\s*\n([\s\S]*?)\n```').firstMatch(answer);
  if (match == null) return null;
  return jsonDecode(match.group(1)!) as Map<String, dynamic>;
}

/// Models sometimes wrap notation in a Markdown fence despite the request.
String notationText(String answer) => answer
    .trim()
    .replaceFirst(RegExp(r'^```(?:notation)?\s*\n'), '')
    .replaceFirst(RegExp(r'\n```\s*$'), '');

class Trial {
  Trial(this.name, this.request, this.session);
  final String name, request;
  final UiSession session;
  String first = '', second = '';
  String? error;
  int firstMs = 0, designMs = 0, replacementMs = 0, designTries = 0;
  bool wanted = false, added = false, clean = false;
  List<String> wantedNames = [];
  Map<String, dynamic>? blockJson;
  List<String> problems = [];

  Map<String, Object?> summary() => {
    'name': name,
    'wanted': wanted,
    'wantedNames': wantedNames,
    'firstMs': firstMs,
    'designMs': designMs,
    'replacementMs': replacementMs,
    'designTries': designTries,
    'added': added,
    'clean': clean,
    'problems': problems,
    'error': error,
    'firstNotation': first,
    'secondNotation': second,
    'blockJson': blockJson,
  };
}

Future<Trial> runTrial(
  String name,
  String user,
  DesignSystem cards, {
  void Function(Trial)? changed,
}) async {
  final trial = Trial(name, user, UiSession(designSystem: cards));
  final session = trial.session;
  final watch = Stopwatch()..start();
  try {
    final firstSystem = session.notationInstructions(askForBlocks: true);
    trial.first = await ask(
      'claude-haiku-5-5',
      firstSystem,
      '$user\nWrite one complete card in notation. If no existing block fits the central visual, write a Wanted line for a reusable $name block and draw its temporary plain-type replacement beneath it. Return notation only.',
    );
    final firstResult = await session.applyNotation(
      Stream.value(notationText(trial.first)),
    );
    trial.firstMs = watch.elapsedMilliseconds;
    changed?.call(trial);
    trial.wanted = session.wantedBlocks.any((w) => w.name == name);
    trial.wantedNames = session.wantedBlocks.map((w) => w.name).toList();
    if (!firstResult.ok || session.notationIssues.isNotEmpty) {
      trial.problems.add(
        'first apply: ${firstResult.toModelJson()} ; notation: ${session.notationIssues}',
      );
    }
    if (!trial.wanted) return trial;
    final blocks = OnDemandBlocks(
      session,
      maxTries: 2,
      design: (wanted, active, notes) async {
        final brief = await designerBrief(wanted.name);
        final answer = await ask(
          'claude-opus-5-5',
          brief,
          'THE BLOCK TO DESIGN: ${wanted.name}\n${wanted.purpose}\n\nTHE CARD THAT USES IT answers this request:\n$user\n\nFirst card notation:\n${trial.first}\n\nProblems from the last try: ${notes.join('; ')}',
          maxTokens: 16000,
        );
        return jsonFence(answer);
      },
    );
    final outcomes = await blocks.designWanted();
    final outcome = outcomes.firstWhere((o) => o.wanted.name == name);
    trial.designTries = outcome.tries;
    trial.designMs = watch.elapsedMilliseconds - trial.firstMs;
    trial.added = outcome.added;
    if (outcome.definition != null)
      trial.blockJson = outcome.definition!.toJson();
    trial.problems.addAll(outcome.problems);
    if (!outcome.added) return trial;
    final secondSystem = session.notationInstructions();
    trial.second = await ask(
      'claude-haiku-5-5',
      secondSystem,
      '$user\nWrite the complete card again, now using the new $name block for the central visual. Return notation only.',
    );
    final secondResult = await session.applyNotation(
      Stream.value(notationText(trial.second)),
      replace: true,
    );
    trial.replacementMs = watch.elapsedMilliseconds;
    trial.clean =
        secondResult.ok &&
        session.notationIssues.isEmpty &&
        session.document.roots.length == 1 &&
        session.document.nodes.values.any((node) => node.type == name);
    if (!trial.clean)
      trial.problems.add(
        'replacement: ${secondResult.toModelJson()} ; notation: ${session.notationIssues}',
      );
    changed?.call(trial);
  } catch (e) {
    trial.error = '$e';
  }
  return trial;
}

void main() => runApp(const Run9App());

class Run9App extends StatefulWidget {
  const Run9App({super.key});
  @override
  State<Run9App> createState() => _Run9AppState();
}

class _Run9AppState extends State<Run9App> {
  final trials = <Trial>[];
  bool running = false;

  Future<void> run() async {
    if (running) return;
    setState(() {
      running = true;
      trials.clear();
    });
    final cards = await loadCards();
    for (final (name, request) in requests) {
      final trial = await runTrial(
        name,
        request,
        cards,
        changed: (trial) {
          if (mounted)
            setState(() {
              if (!trials.contains(trial)) trials.add(trial);
            });
        },
      );
      if (!mounted) break;
      setState(() {
        if (!trials.contains(trial)) trials.add(trial);
      });
    }
    if (mounted) setState(() => running = false);
  }

  @override
  void dispose() {
    for (final trial in trials) {
      trial.session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('On-demand cards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: running ? null : run,
        label: Text(running ? 'Running…' : 'Run three requests'),
      ),
      body: ListView(
        children: [
          for (final trial in trials)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trial.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Wanted: ${trial.wanted}; added: ${trial.added}; clean: ${trial.clean}; ${trial.replacementMs} ms',
                    ),
                    SizedBox(
                      height: 420,
                      child: CodelesslyView(session: trial.session),
                    ),
                    if (trial.error != null) Text(trial.error!),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
