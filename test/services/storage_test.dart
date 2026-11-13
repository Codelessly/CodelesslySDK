import 'dart:async';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

// ignore: depend_on_referenced_packages
class RejectWrites extends InMemorySharedPreferencesStore {
 RejectWrites():super.empty();
 @override Future<bool> setValue(String valueType,String key,Object value)async=>false;
}

void main() {
  test('a write the device refuses fails, changes nothing and tells no one',()async{
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
  test('a cache keeps and removes what it is given', () async {
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

  test('storage tells the readers of a key when it changes', () async {
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

  test('stored values persist on the device under the app\'s prefix', () async {
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

  test('a cloud file path cannot leave its root folder', () {
    expect(CloudFilePaths.folderFor(root: 'data/p', folder: '../a//b/'), 'data/p/a/b');
    expect(CloudFilePaths.folderFor(root: 'data/p', folder: 'pics', access: CloudFileAccess.private, uid: 'u1'),
        'data/p/users/u1/pics');
    expect(() => CloudFilePaths.folderFor(root: 'r', folder: 'x', access: CloudFileAccess.private), throwsStateError);
    expect(CloudFilePaths.contentTypeFor('PNG'), 'image/png');
    expect(CloudFilePaths.contentTypeFor('zip'), 'application/octet-stream');
  });

  test('files can be stored, read and removed', () async {
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

  group('closing a project', () {
    test('closing a project closes the services it created', () async {
      final project = Codelessly();
      final services = project.services as Services;
      final storage = services.storage as ChangeNotifier;
      project.dispose();
      await Future<void>.delayed(Duration.zero);
      // A FlutterError up to Flutter 3.47; a StateError once ChangeNotifier moved to package:listen.
      expect(() => storage.addListener(() {}), throwsA(anyOf(isFlutterError, isStateError)));
    });
    test('closing a project leaves the services the app passed in to the app', () async {
      final services = Services();
      final project = Codelessly(config: CodelesslyConfig(services: services));
      project.dispose();
      final storage = services.storage as ChangeNotifier;
      void listener() {}
      storage.addListener(listener);
      storage.removeListener(listener);
      await services.dispose();
    });
  });
}
