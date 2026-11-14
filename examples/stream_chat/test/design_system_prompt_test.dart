// The chat with the SSUI design system: its prompt is generated from the
// bundled design system, and a session given it takes its components.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/src/llm.dart';

DesignSystem _ssui() => DesignSystem.fromJson(jsonDecode(File('assets/design_systems/ssui.json').readAsStringSync()));

void main() {
  test('the prompt with SSUI lists its components instead of the base controls', () {
    final ds = _ssui();
    final plain = systemPromptFor(PromptVariant.compact, full: '');
    final prompt = systemPromptFor(PromptVariant.compact, full: '', designSystem: ds);
    expect(prompt, contains('## The design system: Soft SaaS UI'));
    expect(prompt, contains('**`Button`**'));
    expect(prompt, contains('**`TextInput`**'));
    expect(RegExp(r'^\| `filledButton` \(ui_docs', multiLine: true).hasMatch(prompt), isFalse);
    expect(RegExp(r'^\| `filledButton` \(ui_docs', multiLine: true).hasMatch(plain), isTrue);
    // The generated prompt in the assets is the current one.
    expect(File('assets/system_prompt.ssui.md').readAsStringSync(), prompt);
  });

  test('ui_docs answers SSUI\'s principles, patterns and each component', () {
    final ds = _ssui();
    final doc = answerLookup('ui_docs', {'topic': 'Select'}, document: LayoutDocument(), designSystem: ds);
    expect('$doc', contains('# `Select`'));
    expect('${answerLookup('ui_docs', {'topic': 'patterns'}, document: LayoutDocument(), designSystem: ds)}', contains('Inline card'));
  });
}
