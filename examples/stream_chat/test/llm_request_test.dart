// The live source's request, checked without a network: the two tools with
// eager input streaming, the generated system prompt (cached), thinking
// off for the fast model, low effort. No request is sent.
import 'dart:convert';
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/src/llm.dart';

void main() {
  test('the request a live reply streams', () {
    final model = UiModel(apiKey: 'not-a-key', model: kDefaultModel, systemPrompt: File('assets/system_prompt.md').readAsStringSync(), tools: uiToolsForAgent());
    model.messages.add(InputMessage.user(userMessage(kBriefs['flights']!.prompt, 'card')));
    final j = jsonDecode(jsonEncode(model.buildRequest().toJson())) as Map<String, Object?>;
    expect(j['model'], 'claude-haiku-5-5');
    final tools = (j['tools']! as List).cast<Map<String, Object?>>();
    expect([for (final t in tools) t['name']], ['ui_apply', 'ui_read']);
    expect(tools.every((t) => t['eager_input_streaming'] == true), isTrue);
    expect(((tools.first['input_schema']! as Map)['properties']! as Map).keys, containsAll(['ops', 'baseRev']));
    expect((j['thinking']! as Map)['type'], 'disabled');
    expect((j['output_config']! as Map)['effort'], 'low');
    final system = (j['system']! as List).single as Map;
    expect(system['cache_control'], isNotNull);
    expect(system['text'], contains('# The authoring guide'));
    expect(jsonEncode(j), isNot(contains('not-a-key')));
    model.close();
  });

  test('the record command refuses to run without a key', () async {
    final r = await Process.run('dart', ['run', 'tool/record.dart', '--ui', 'flights'], environment: {'ANTHROPIC_API_KEY': ''});
    expect(r.exitCode, 2);
    expect('${r.stderr}', contains('ANTHROPIC_API_KEY is not set'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
