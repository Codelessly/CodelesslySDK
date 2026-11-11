import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Json> _panels(String prefix) => {
  prefix: {
    'type': 'column',
    'layout': {
      'width': {'fill': 700},
      'height': {'hug': 200},
    },
    'children': ['${prefix}signed', '${prefix}guest'],
  },
  for (final signed in [true, false])
    '$prefix${signed ? 'signed' : 'guest'}': {
      'type': 'column',
      'layout': {
        'width': {'fill': 700},
        'height': {'hug': 200},
      },
      'props': {'spacing': 12, 'crossAxisAlignment': 'start'},
      'bind': {'visible': signed ? r'${= auth.isSignedIn && !guest}' : r'${= guest || !auth.isSignedIn}'},
      'children': ['$prefix${signed ? 'signed' : 'guest'}header', '$prefix${signed ? 'signed' : 'guest'}body'],
    },
  for (final kind in ['signed', 'guest']) ...{
    '$prefix${kind}header': {
      'type': 'text',
      'layout': {
        'width': {'fill': 700},
        'height': {'hug': 30},
      },
      'props': {'text': r'Account ${auth.displayName}'},
    },
    '$prefix${kind}body': {
      'type': 'column',
      'layout': {
        'width': {'fill': 700},
        'height': {'hug': 100},
      },
      'children': ['$prefix${kind}text'],
    },
    '$prefix${kind}text': {
      'type': 'text',
      'layout': {
        'width': {'fill': 700},
        'height': {'hug': 60},
      },
      'props': {'text': r'Guest state: ${guest}. ${auth.displayName}'},
    },
  },
};
void main() {
  testWidgets('attached collapsed panels survive repeated guest/auth preview changes and responsive switches', (tester) async {
    final services = ValuesScope({
      'auth': {'isSignedIn': true, 'displayName': 'Ada'},
    });
    final variables = VariableScope([const Variable(name: 'guest', type: VariableType.boolean, value: false)], parent: services);
    final nodes = <String, Json>{
      'root': {
        'type': 'canvas',
        'layout': {'width': 700, 'height': 600},
        'slots': {'body': 'responsive'},
      },
      'responsive': {
        'type': 'variance',
        'layout': {'width': 700, 'height': 600},
        'props': {
          'current': 'tablet',
          'variants': [
            for (final bp in ['mobile', 'tablet', 'desktop'])
              {
                'id': bp,
                'breakpoint': bp,
                'children': ['${bp}panel'],
              },
          ],
        },
      },
      for (final bp in ['mobile', 'tablet', 'desktop']) ..._panels('${bp}panel'),
    };
    final document = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': nodes,
    });
    final tree = NodeTree(DocumentSource(document), binder: NodeBinder(scope: variables, preview: true));
    tree.responsive = ResponsiveWidth(Breakpoints.defaults, 834);
    addTearDown(() {
      tree.dispose();
      variables.dispose();
      services.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: NodeView(tree: tree, rootId: 'root'),
        ),
      ),
    );
    for (final width in [834.0, 390.0, 1440.0, 834.0]) {
      tree.responsive = ResponsiveWidth(Breakpoints.defaults, width);
      await tester.pump();
      final prefix = '${Breakpoints.defaults.forWidth(width).id}panel';
      for (var i = 0; i < 5; i++) {
        services.set('auth', {'isSignedIn': true, 'displayName': 'Account $i'});
        variables.set('guest', false);
        await tester.pump();
        expect(tree.boxOf('${prefix}signed')!.collapsed, false);
        variables.set('guest', true);
        await tester.pump();
        expect(tree.boxOf('${prefix}signed')!.collapsed, true);
        expect(tree.boxOf('${prefix}signed')!.size.height, 0, reason: 'offstage layout must not take space');
        // Updating a retained hidden subtree after its collapsed parent was
        // laid out must not leave a dirty child under a clean boundary.
        services.set('auth', {'isSignedIn': false, 'displayName': 'Guest $i'});
        await tester.pump();
        variables.set('guest', true);
        await tester.pump();
        expect(tree.boxOf('${prefix}guest')!.collapsed, false);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
