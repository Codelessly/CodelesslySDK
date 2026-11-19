// A theme font that loads after the first layout (round 11b: a site whose
// theme names Lato with no file): the controls' own texts (a checkbox's and a
// toggle's label, a field's hint, a tab's label) are measured again and drawn
// in it, as the text nodes beside them are, and the tree asks for the theme
// family at the weights the controls draw in.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/src/render/controls/kit.dart' show ControlLabel;
import 'package:codelessly_sdk/src/render/convert.dart' show FontDemand;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  tearDown(() => FontDemand.handler = null);

  testWidgets('a font change lays a control label out again', (tester) async {
    final label = ControlLabel()..update('Add Gift Aid', const TextStyle(fontSize: 13));
    label.layout(200);
    final epoch = ControlLabel.fontEpoch;
    await tester.binding.handleSystemMessage(<String, Object?>{'type': 'fontsChange'});
    expect(ControlLabel.fontEpoch, epoch + 1);
  });

  testWidgets('the tree asks for its theme family at the controls\' weights', (tester) async {
    final asked = <String>[];
    FontDemand.handler = (family, weight, italic) => asked.add('$family $weight');
    final (tree, _) = runningTree(columnDoc({'t': {'type': 'text', 'props': {'text': 'a'}}}));
    addTearDown(tree.dispose);
    tree.textDefault = const api.TextStyle(fontFamily: 'Round11bTheme');
    expect(asked, ['Round11bTheme 400', 'Round11bTheme 500', 'Round11bTheme 600', 'Round11bTheme 700']);
  });
}
