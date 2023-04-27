import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import '../auth/auth_manager.dart';
import '../cache/cache_manager.dart';
import '../error/error_handler.dart';
import 'local_data_repository.dart';
import 'network_data_repository.dart';

enum DataManagerStatus {
  /// The data manager has not been initialized.
  idle,

  /// The data manager is currently initializing.
  initializing,

  /// The data manager has been initialized.
  initialized,
}

/// Abstraction for loading UI data from a remote source.
class DataManager {
  bool initialized = false;

  /// The passed config from the SDK.
  final CodelesslyConfig config;

  final NetworkDataRepository networkDataRepository;
  final LocalDataRepository localDataRepository;
  final CacheManager cacheManager;
  final AuthManager authManager;

  SDKPublishModel? _publishModel;

  SDKPublishModel? get publishModel => _publishModel;

  StreamController<SDKPublishModel?> _publishModelStreamController =
      StreamController<SDKPublishModel?>.broadcast();

  Stream<SDKPublishModel?> get publishModelStream =>
      _publishModelStreamController.stream;

  StreamSubscription<SDKPublishModel?>? _publishModelDocumentListener;

  /// Creates a new instance of [DataManager] with the given [config].
  DataManager({
    required this.config,
    required this.cacheManager,
    required this.authManager,
    required this.networkDataRepository,
    required this.localDataRepository,
  });

  /// Initializes the [DataManager] instance.
  ///
  /// If a [layoutID] is specified, that layout will be downloaded from the
  /// server first, then the rest of the layouts will be streamed passively
  /// in the background.
  ///
  /// If a [layoutID] is not specified, all layouts will be streamed
  /// immediately and awaited.
  Future<void> init({required String? layoutID}) async {
    initialized = true;

    // Initialize all locally cached data.
    _publishModel = localDataRepository.fetchPublishModel(
      isPreview: config.isPreview,
    );

    if (_publishModel != null) {
      print('Publish model is cached locally. Emitting.');
      emitPublishModel();

      for (final SDKPublishFont font in _publishModel!.fonts.values) {
        print('\tLoading font in init: [${font.id}](${font.fullFontName})');
        final Uint8List? fontBytes = localDataRepository.fetchFontBytes(
          fontID: font.id,
          isPreview: config.isPreview,
        );
        if (fontBytes != null) {
          loadFont(font, fontBytes);
        } else {
          // If a font's bytes are missing from cache, it should be
          // downloaded again. Should runs in the background.
          //
          // Authentication is not needed to download public font files.
          print(
              "\tFont bytes from init doesn't exist, downloading [${font.id}](${font.fullFontName}) bytes...");
          downloadFontBytesAndSave(font).then((fontBytes) {
            if (fontBytes == null) return null;
            loadFont(font, fontBytes);
          });
        }
      }
    }

    if (authManager.authData == null) return;

    final AuthData authData = authManager.authData!;

    // If a [layoutID] is not null, then that layout must be prioritized and
    // downloaded first if it is not already cached.
    //
    // If the publish model is still null, then that needs to be downloaded
    // first, and we do that by getting the first event of the stream below.
    //
    // Once a publish model is available in the future, if a [layoutID] is
    // specified, we try to download that layout then instead of here.
    final bool didPrepareLayout;
    if (_publishModel != null && layoutID != null) {
      if (!_publishModel!.layouts.containsKey(layoutID)) {
        print(
            'Layout [$layoutID] during init is not cached locally. Downloading...');
        didPrepareLayout = await getOrFetchLayoutWithFontsAndEmit(
          layoutID: layoutID,
        );
        print('Layout in init [$layoutID] download complete.');
      } else {
        print(
            'Layout [$layoutID] during init is already cached locally. Skipping layout download.');
        didPrepareLayout = true;
      }
    } else {
      if (_publishModel == null) {
        print(
            'Publish model during init is not cached locally. Going to wait for the first publish model from the server.');
      } else if (layoutID == null) {
        print(
            'Publish model during init is available and layout [$layoutID] is not specified.');
      }
      didPrepareLayout = false;
    }

    // Listen the publish model document.
    // It's either going to be fetched for the first time if it doesn't exist
    // in cache, or it's going to be updated with new data.
    final Completer<SDKPublishModel> completer = Completer();
    _publishModelDocumentListener?.cancel();
    _publishModelDocumentListener = networkDataRepository
        .streamPublishModel(
      projectID: authData.projectId,
      isPreview: config.isPreview,
    )
        .listen((SDKPublishModel? serverModel) {
      if (serverModel == null) return;

      print('Publish model stream event received.');

      final bool isFirstEvent = !completer.isCompleted;

      // If the completer has not completed yet, it needs to be
      // completed with the first available publish model form the server.
      if (isFirstEvent) {
        print(
            'Completing publish model stream completer since this is the first event.');
        completer.complete(serverModel);
      }

      // If the publish model is null, meaning no publish model was previously
      // cached, then this is the first available publish model we have that
      // just arrived from the server.
      //
      // We can skip publish model comparison as there is nothing to compare
      // to yet.
      //
      // Since it is null, it will be hydrated with a value outside of this
      // listener when the completer completes. The publish model is emitted
      // once that happens, therefore we don't need to emit it here, nor
      // compare.
      if (_publishModel == null) {
        print(
            'Publish model is null during init and received the first publish model from the server. Skipping comparison in stream.');
        return;
      }

      if (isFirstEvent) {
        print(
            'Publish model during init was not null, and we received a new publish model from the server. Comparing...');
      } else {
        print('Received a second publish model from the server. Comparing...');
      }
      final SDKPublishModel localModel = _publishModel!;
      processPublishDifference(
        projectID: authData.projectId,
        serverModel: serverModel,
        localModel: localModel,
      );

      print('Publish model comparison complete.');
    });

    // If the publish model is still null, then we need to wait for the first
    // publish model to arrive from the server via the stream above.
    if (_publishModel == null) {
      print(
        'Publish model is still null during init. Waiting for the first publish model from the server.',
      );
      _publishModel = await completer.future;
      emitPublishModel();
      savePublishModel();

      print(
          'Publish model during init is now available. Proceeding with init!');
    }

    if (_publishModel == null) {
      print(
        'Publish model is still null.\n'
        'Is there a network problem or bad authentication?',
      );
      return;
    }

    // If a [layoutID] was specified, then that layout must be prioritized and
    // downloaded first if it is not already cached.
    //
    // If we could not download it earlier, that would be because we did not
    // have a publish model available and needed to wait for one to arrive
    // from the server for the first time or that it failed to download for some
    // unknown reason.
    //
    // Perhaps the publish model was simply out of date locally,
    // but now that we fetched a new one, and didPrepareLayout is still false,
    // we can try to download the layout again with the new publish model.
    //
    // At this stage of the function, we can be sure that a publish model exists
    // and can safely download the desired [layoutID], because if a publish
    // model is still null, we cannot proceed further and this function
    // terminates earlier.
    if (!didPrepareLayout && layoutID != null) {
      print(
        'Publish model is definitely available. We can safely download layout [$layoutID] now.',
      );
      await getOrFetchLayoutWithFontsAndEmit(layoutID: layoutID);

      print(
        'Layout [$layoutID] during init download complete.',
      );
    }

    // If a [layoutID] is not specified, then we need to download all layouts
    // in the background.
    if (layoutID == null) {
      print(
        'No layout ID was specified during init. Downloading all layouts in the background.',
      );
      for (final String layoutID in _publishModel!.layouts.keys) {
        getOrFetchLayoutWithFontsAndEmit(layoutID: layoutID);
      }

      print(
        'All layouts during init download complete.',
      );
    }

    print('Init complete.');
  }

  void emitPublishModel() {
    _publishModelStreamController.add(_publishModel);
  }

  void savePublishModel() {
    if (_publishModel != null) {
      localDataRepository.savePublishModel(
        model: _publishModel!,
        isPreview: config.isPreview,
      );
    }
  }

  void saveFontBytes(SDKPublishFont font, Uint8List fontBytes) {
    localDataRepository.saveFontBytes(
      fontID: font.id,
      bytes: fontBytes,
      isPreview: config.isPreview,
    );
  }

  /// Disposes the [DataManager] instance.
  void dispose() async {
    _publishModelStreamController.close();
    _publishModelDocumentListener?.cancel();
  }

  /// Sets the [SDKPublishModel] as null.
  void invalidate() async {
    _publishModelDocumentListener?.cancel();
  }

  Future<void> processPublishDifference({
    required String projectID,
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) async {
    final Map<String, UpdateType> layoutUpdates = _collectLayoutUpdates(
      serverModel: serverModel,
      localModel: localModel,
    );
    final Map<String, UpdateType> fontUpdates = _collectFontUpdates(
      serverModel: serverModel,
      localModel: localModel,
    );

    if (layoutUpdates.isEmpty && fontUpdates.isEmpty) {
      print('No updates to process.');
      return;
    } else {
      print(
          'Processing ${layoutUpdates.length} layout updates and ${fontUpdates.length} font updates.');
    }

    for (final String layoutID in layoutUpdates.keys) {
      final UpdateType updateType = layoutUpdates[layoutID]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.layouts.remove(layoutID);
          break;
        case UpdateType.add:
        case UpdateType.update:
          final SDKPublishLayout? layout =
              await networkDataRepository.downloadLayoutModel(
            projectID: projectID,
            layoutID: layoutID,
            isPreview: config.isPreview,
          );
          if (layout != null) {
            localModel.layouts[layoutID] = layout;
          }
          break;
      }
    }

    for (final String fontID in fontUpdates.keys) {
      final UpdateType updateType = fontUpdates[fontID]!;

      switch (updateType) {
        case UpdateType.delete:
          localModel.fonts.remove(fontID);
          localDataRepository.deleteFontBytes(
            fontID: fontID,
            isPreview: config.isPreview,
          );
          break;
        case UpdateType.add:
        case UpdateType.update:
          final SDKPublishFont? font =
              await networkDataRepository.downloadFontModel(
            projectID: projectID,
            fontID: fontID,
            isPreview: config.isPreview,
          );

          if (font != null) {
            localModel.fonts[fontID] = font;
            downloadFontBytesAndSave(font).then((fontBytes) {
              if (fontBytes == null) return null;
              loadFont(font, fontBytes);
            });
          }
          break;
      }
    }

    _publishModel = localModel.copyWith(
      updates: serverModel.updates,
    );
    savePublishModel();
    emitPublishModel();
  }

  /// Compares the current [_publishModel] with the newly fetched
  /// [serverModel] and returns a map of layout ids and their corresponding
  /// update type.
  ///
  /// - If a layout did not exist in the previous model, it is marked for
  /// download.
  ///
  /// - If a layout exists in both models but has a newer time stamp, it is
  /// marked for download.
  ///
  /// - If a layout existed in the previous model, but was deleted in the
  /// updated model, it is marked for deletion.
  Map<String, UpdateType> _collectLayoutUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverLayouts = serverModel.updates.layouts;
    final Map<String, DateTime> currentLayouts = localModel.updates.layouts;
    final Map<String, UpdateType> layoutUpdates = {};

    // Check for deleted layouts.
    for (final String layoutID in currentLayouts.keys) {
      if (!serverLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.delete;
      }
    }

    // Check for added or updated layouts.
    for (final String layoutID in serverLayouts.keys) {
      if (!currentLayouts.containsKey(layoutID)) {
        layoutUpdates[layoutID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentLayouts[layoutID]!;
        final DateTime newlyUpdated = serverLayouts[layoutID]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          layoutUpdates[layoutID] = UpdateType.update;
        }
      }
    }

    return layoutUpdates;
  }

  Map<String, UpdateType> _collectFontUpdates({
    required SDKPublishModel serverModel,
    required SDKPublishModel localModel,
  }) {
    final Map<String, DateTime> serverFonts = serverModel.updates.fonts;
    final Map<String, DateTime> currentFonts = localModel.updates.fonts;
    final Map<String, UpdateType> fontUpdates = {};

    // Check for deleted fonts.
    for (final String fontID in currentFonts.keys) {
      if (!serverFonts.containsKey(fontID)) {
        fontUpdates[fontID] = UpdateType.delete;
      }
    }

    // Check for added or updated fonts.
    for (final String fontID in serverFonts.keys) {
      if (!currentFonts.containsKey(fontID)) {
        fontUpdates[fontID] = UpdateType.add;
      } else {
        final DateTime lastUpdated = currentFonts[fontID]!;
        final DateTime newlyUpdated = serverFonts[fontID]!;
        if (newlyUpdated.isAfter(lastUpdated)) {
          fontUpdates[fontID] = UpdateType.update;
        }
      }
    }

    return fontUpdates;
  }

  /// If the layout were cached during initialization, then it's already been
  /// loaded. So we can skip checking cache and load from server directly.
  Future<bool> getOrFetchLayoutWithFontsAndEmit({
    required String layoutID,
  }) async {
    final SDKPublishModel? model = _publishModel;
    final AuthData? auth = authManager.authData;
    assert(
      model != null,
      'Data manager has not been initialized yet.',
    );

    // If the user is not authenticated, then they get whatever is cached and
    // nothing else.
    if (auth == null) return false;

    SDKPublishLayout? layout;
    if (model!.layouts.containsKey(layoutID)) {
      print('\tlayout [$layoutID] already cached. On Your Marks...');
      layout = model.layouts[layoutID];
    } else {
      print('\tlayout [$layoutID] not cached. On Your Marks...');
      layout = await networkDataRepository.downloadLayoutModel(
        layoutID: layoutID,
        projectID: auth.projectId,
        isPreview: config.isPreview,
      );

      if (layout == null) return false;

      model.layouts[layoutID] = layout;
      emitPublishModel();
      savePublishModel();
    }

    assert(layout != null, 'Layout should not be null at this point.');

    print('\tLayoutModel [$layoutID] ready, time for fonts. Get Set...');

    // Download or load fonts in the background.
    final Set<Future<SDKPublishFont?>> fontModels = getOrFetchFontModels(
      projectID: auth.projectId,
      fontIDs: model.updates.layoutFonts[layoutID]!,
    );

    print('\tFound ${fontModels.length} to fonts to fetch. Go!');
    for (final Future<SDKPublishFont?> fontModel in fontModels) {
      fontModel.then((SDKPublishFont? fontModel) {
        if (fontModel == null) return;
        print(
            '\t\tFontModel [${fontModel.id}] ready. Fetching bytes & loading...');

        model.fonts[fontModel.id] = fontModel;

        getOrFetchFontBytesAndSaveAndLoad(fontModel);
        print('\t\tFontModel [${fontModel.id}] loaded. Done!\n');
      });
    }

    return true;
  }

  Future<SDKPublishLayout?> getOrFetchLayoutModel({
    required String layoutID,
    required String projectID,
  }) async {
    final SDKPublishModel? model = _publishModel;

    if (model != null && model.layouts.containsKey(layoutID)) {
      print('Layout [$layoutID] is already saved. Done!');
      return model.layouts[layoutID]!;
    } else {
      print('\tLayout [$layoutID] is not saved, downloading...');
      final SDKPublishLayout? layout =
          await networkDataRepository.downloadLayoutModel(
        layoutID: layoutID,
        projectID: projectID,
        isPreview: config.isPreview,
      );
      print('\tLayout [$layoutID] downloaded. Done!');
      return layout;
    }
  }

  Future<void> getOrFetchFontBytesAndSaveAndLoad(SDKPublishFont font) async {
    final Uint8List? fontBytes = await getOrFetchFontBytesAndSave(font);
    if (fontBytes == null) return;

    return loadFont(font, fontBytes);
  }

  Future<void> loadFont(SDKPublishFont font, Uint8List fontBytes) async {
    final FontLoader fontLoader = FontLoader(font.fullFontName);

    fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));

    return fontLoader.load();
  }

  /// Also saves to cache.
  Future<Uint8List?> getOrFetchFontBytesAndSave(SDKPublishFont font) async {
    final Uint8List? fontBytes = localDataRepository.fetchFontBytes(
      fontID: font.id,
      isPreview: config.isPreview,
    );
    if (fontBytes != null) {
      print('\t\tFont [${font.id}] bytes already cached.');
      return Future.value(fontBytes);
    } else {
      print('\t\tFont [${font.id}] bytes not cached. Downloading...');
      return downloadFontBytesAndSave(font);
    }
  }

  Future<Uint8List?> downloadFontBytesAndSave(SDKPublishFont font) async =>
      networkDataRepository.downloadFontBytes(url: font.url).then(
        (Uint8List? fontBytes) {
          // Save the font bytes to cache.
          if (fontBytes == null) return null;
          saveFontBytes(font, fontBytes);
          return fontBytes;
        },
      );

  Set<Future<SDKPublishFont?>> getOrFetchFontModels({
    required String projectID,
    required Set<String> fontIDs,
  }) {
    final Set<Future<SDKPublishFont?>> fonts = {};
    for (final String fontID in fontIDs) {
      final SDKPublishFont? font = _publishModel?.fonts[fontID];
      if (font != null) {
        fonts.add(Future.value(font));
      } else {
        final Future<SDKPublishFont?> fontModelFuture =
            networkDataRepository.downloadFontModel(
          projectID: projectID,
          fontID: fontID,
          isPreview: config.isPreview,
        );
        fonts.add(fontModelFuture);
      }
    }
    return fonts;
  }
}
