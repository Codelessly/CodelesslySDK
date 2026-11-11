import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'provided item changes are immediate to readers and coalesced for listeners',
    () async {
      final scope = ItemScope(
        index: 0,
        item: {
          'values': [1, 2],
        },
      );
      var notifications = 0;
      scope.watch('item').addListener(() => notifications++);
      scope.update(
        index: 0,
        item: {
          'values': [1, 2],
        },
        deferNotifications: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 0);
      scope.update(
        index: 0,
        item: {
          'values': [3],
        },
        deferNotifications: true,
      );
      scope.update(
        index: 1,
        item: {
          'values': [4],
        },
        deferNotifications: true,
      );
      expect(scope.read('item.values'), [4]);
      expect(scope.index, 1);
      expect(notifications, 0);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      scope.dispose();
    },
  );

  test('disposing an item cancels queued listener delivery', () async {
    final scope = ItemScope(index: 0, item: 'old');
    scope.update(index: 0, item: 'new', deferNotifications: true);
    scope.dispose();
    await Future<void>.delayed(Duration.zero);
  });
}
