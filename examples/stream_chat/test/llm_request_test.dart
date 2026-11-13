// The live source's request, checked without a network: the two tools with
// eager input streaming, the generated system prompt (cached), thinking
// off for the fast model, low effort. No request is sent.
import 'dart:convert';
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart' show LayoutDocument;
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/src/llm.dart';

void main() {
  test('the request a live reply streams: full prompt', () {
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
    // A turn cannot end without a tool call where the model allows forcing it.
    expect((j['tool_choice']! as Map)['type'], 'any');
    final system = (j['system']! as List).single as Map;
    expect(system['cache_control'], isNotNull);
    expect(system['text'], contains('# The authoring guide'));
    expect(jsonEncode(j), isNot(contains('not-a-key')));
    model.close();
  });

  test('the compact prompt: the base set, compact tools and ui_docs; auto where forcing is a 400', () {
    for (final m in kModels) {
      final model = UiModel(
          apiKey: 'not-a-key', model: m, systemPrompt: systemPromptFor(PromptVariant.compact, full: ''), tools: uiToolsFor(PromptVariant.compact));
      model.messages.add(InputMessage.user('Hi'));
      final j = jsonDecode(jsonEncode(model.buildRequest().toJson())) as Map<String, Object?>;
      final tools = (j['tools']! as List).cast<Map<String, Object?>>();
      expect([for (final t in tools) t['name']], ['ui_apply', 'ui_read', 'ui_docs']);
      expect((j['tool_choice']! as Map)['type'], m == 'claude-haiku-5-5' ? 'any' : 'auto', reason: m);
      final text = ((j['system']! as List).single as Map)['text'] as String;
      // The base, runtime form: it ends with the index of ui_docs topics.
      expect(text, allOf(contains('## Index'), contains('"forms-validation-and-an-error-state"')));
      expect(text.length, lessThan(50000));
      model.close();
    }
    // An app brief with scripts on gets the scripts op and its rule.
    final apps = systemPromptFor(PromptVariant.compact, full: '', kind: 'app', profile: profileFor('app'));
    expect(apps, contains('- `scripts` ('));
    expect(systemPromptFor(PromptVariant.compact, full: '', kind: 'app', profile: profileFor('app', scripts: false)), isNot(contains('- `scripts` (')));
    // Lookups are answered from the declarations.
    expect('${answerLookup('ui_docs', {'topic': 'slider'}, document: LayoutDocument())}', contains('`value`'));
  });

  test('the record command refuses to run without a key', () async {
    final r = await Process.run('dart', ['run', 'tool/record.dart', '--ui', 'flights'], environment: {'ANTHROPIC_API_KEY': ''});
    expect(r.exitCode, 2);
    expect('${r.stderr}', contains('ANTHROPIC_API_KEY is not set'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
