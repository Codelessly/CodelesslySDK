import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../../codelessly_sdk.dart';
import '../cache/cache_manager.dart';

class LocalDataRepository {
  /// The cache manager used to store the the published model and associated
  /// layouts and font files.
  final CacheManager cacheManager;

  LocalDataRepository({required this.cacheManager});

  String modelCacheKey(bool isPreview) {
    return isPreview ? previewModelCacheKey : publishModelCacheKey;
  }

  String fontsCacheKey(bool isPreview) {
    return isPreview ? previewFontsCacheKey : publishFontsCacheKey;
  }

  SDKPublishModel? fetchPublishModel({
    required bool isPreview,
  }) {
    try {
      return cacheManager.get(
        modelCacheKey(isPreview),
        decode: SDKPublishModel.fromJson,
      );
    } catch (e) {
      return null;
    }
  }

  Uint8List? fetchFontBytes({
    required String fontID,
    required bool isPreview,
  }) {
    try {
      return cacheManager.getBytes(fontsCacheKey(isPreview), fontID);
    } catch (e) {
      return null;
    }
  }

  Future<void> savePublishModel({
    required SDKPublishModel model,
    required bool isPreview,
  }) =>
      cacheManager.store(
        modelCacheKey(isPreview),
        model.toFullJson(),
      );

  Future<void> saveFontBytes({
    required String fontID,
    required Uint8List bytes,
    required bool isPreview,
  }) =>
      cacheManager
          .storeBytes(
        fontsCacheKey(isPreview),
        fontID,
        bytes,
      )
          .catchError((e, str) {
        debugPrintStack(label: '$e', stackTrace: str);
      });

  void deletePublishModel({
    required String layoutID,
    required bool isPreview,
  }) =>
      cacheManager.delete(modelCacheKey(isPreview));

  void deleteFontBytes({
    required String fontID,
    required bool isPreview,
  }) =>
      cacheManager.deleteBytes(fontsCacheKey(isPreview), fontID);
}
