import 'package:codelessly_sdk/src/engage/host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the memory host tracks, answers calls and reports identity changes',
    () async {
      final host = MemoryEngageHost(
        handlers: {
          'inbox/list': (body) => {'cards': [], 'echo': body['n']},
        },
      );
      final seen = <String>[];
      host.events.listen((e) => seen.add(e.name));
      host.track('opened', {'screen': 'home'});
      expect(seen, ['opened']);
      expect(host.tracked.single.properties, {'screen': 'home'});
      expect(await host.call('inbox/list', {'n': 2}), {'cards': [], 'echo': 2});
      await expectLater(
        host.call('missing'),
        throwsA(isA<EngageUnavailable>()),
      );
      final ids = <String>[];
      host.identityChanges.listen((i) => ids.add(i.id));
      expect(host.identity.id, 'anon');
      host.identity = const EngageIdentity(anonymousId: 'anon', userId: 'u1');
      expect(ids, ['u1']);
      await host.dispose();
    },
  );
}
