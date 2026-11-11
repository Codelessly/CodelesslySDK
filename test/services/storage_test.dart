import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
class RejectWrites extends InMemorySharedPreferencesStore {
 RejectWrites():super.empty();
 @override Future<bool> setValue(String valueType,String key,Object value)async=>false;
}


void main() {
  test('rejected preference writes fail without notifying or changing runtime data',()async{
    SharedPreferences.setMockInitialValues({});
    final original=SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance=RejectWrites();
    addTearDown((){SharedPreferencesStorePlatform.instance=original;SharedPreferences.setMockInitialValues({});});
    final storage=await PreferencesLocalStorage.open(prefix:'rejected.');
    var notifications=0;storage.addListener(()=>notifications++);
    await expectLater(storage.put('tapes',[1]),throwsStateError);
    expect(storage.get('tapes'),isNull);expect(notifications,0);
    final reopened=await PreferencesLocalStorage.open(prefix:'rejected.');
    expect(reopened.get('tapes'),isNull,reason:'failed SharedPreferences cache entries must not look durable');
    reopened.dispose();
    storage.dispose();
  });
  test('memory caches', () async {
    final cache = MemoryKeyValueCache();
    await cache.write('auth', {'projectId': 'p'});
    expect(await cache.contains('auth'), isTrue);
    expect(await readCached(cache, 'auth', ProjectAccess.fromJson), const ProjectAccess(projectId: 'p'));
    await cache.write('bad', 3);
    expect(await readCached<int>(cache, 'bad', (json) => throw const FormatException()), isNull);
    expect(await cache.contains('bad'), isFalse, reason: 'a value that does not decode is dropped');

    final files = MemoryFileCache();
    await files.write('fonts', 'a.ttf', Uint8List(2));
    await files.write('fonts', 'b.ttf', Uint8List(3));
    await files.purge('fonts', keep: ['b.ttf']);
    expect(await files.contains('fonts', 'a.ttf'), isFalse);
    expect((await files.read('fonts', 'b.ttf'))!.length, 3);
    await files.clear();
    expect(await files.read('fonts', 'b.ttf'), isNull);
  });

  test('memory local storage notifies per key', () async {
    final storage = MemoryLocalStorage();
    var all = 0, name = 0;
    storage.addListener(() => all++);
    storage.listenable('name').addListener(() => name++);
    await storage.put('name', 'Ana');
    await storage.put('age', 3);
    await storage.remove('missing');
    expect(storage.getAll(), {'name': 'Ana', 'age': 3});
    expect((all, name), (2, 1));
    await storage.clear();
    expect((all, name), (3, 2));
    storage.dispose();
  });

  test('preferences local storage persists JSON under its prefix', () async {
    SharedPreferences.setMockInitialValues({'codelessly.p1.cart': '[1,2]', 'other': 'x'});
    final storage = await PreferencesLocalStorage.open(prefix: 'codelessly.p1.');
    expect(storage.getAll(), {
      'cart': [1, 2],
    });
    await storage.put('user', {'name': 'Ana'});
    final reopened = await PreferencesLocalStorage.open(prefix: 'codelessly.p1.');
    expect(reopened.get('user'), {'name': 'Ana'});
    await reopened.clear();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'other'});
  });

  test('cloud file paths stay in their root', () {
    expect(CloudFilePaths.folderFor(root: 'data/p', folder: '../a//b/'), 'data/p/a/b');
    expect(CloudFilePaths.folderFor(root: 'data/p', folder: 'pics', access: CloudFileAccess.private, uid: 'u1'),
        'data/p/users/u1/pics');
    expect(() => CloudFilePaths.folderFor(root: 'r', folder: 'x', access: CloudFileAccess.private), throwsStateError);
    expect(CloudFilePaths.contentTypeFor('PNG'), 'image/png');
    expect(CloudFilePaths.contentTypeFor('zip'), 'application/octet-stream');
  });

  test('memory file storage', () async {
    final files = MemoryFileStorage();
    final file = await files.upload('pics/../a.png', Uint8List(4), contentType: 'image/png');
    expect(file.path, 'pics/a.png');
    expect(file.toValue()['size'], 4);
    await files.upload('pics/deep/b.png', Uint8List(1));
    expect((await files.list('pics')).map((f) => f.name), ['a.png']);
    expect(await files.downloadUrl('pics/a.png'), 'memory://pics/a.png');
    await files.delete(file.url);
    expect(files.files.keys, ['pics/deep/b.png']);
  });
}
