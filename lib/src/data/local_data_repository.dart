import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../../codelessly_sdk.dart';

/// The local data repository is responsible for storing and retrieving the
/// published model and associated layouts and font files from [CacheManager].
class LocalDataRepository {
  /// The cache manager used to store the the published model and associated
  /// layouts and font files.
  final CacheManager cacheManager;

  /// Creates a new [LocalDataRepository] instance with the given
  /// [cacheManager].
  LocalDataRepository({required this.cacheManager});

  /// The cache key for the published model.
  String modelCacheKey(bool isPreview) {
    return isPreview ? previewModelCacheKey : publishModelCacheKey;
  }

  /// The cache key for the font files.
  String fontsCacheKey(bool isPreview) {
    return isPreview ? previewFontsCacheKey : publishFontsCacheKey;
  }

  /// The cache key for the APIs.
  String apisCacheKey(bool isPreview) {
    return isPreview ? previewApisCacheKey : publishApisCacheKey;
  }

  /// The cache key for the APIs.
  String variableCacheKey(bool isPreview) {
    return isPreview ? previewVariablesCacheKey : publishVariablesCacheKey;
  }

  /// Returns the [SDKPublishModel] from the cache.
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

  /// Returns the [SDKPublishLayout] from the cache.
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

  /// Stores the [SDKPublishModel] in the cache.
  Future<void> savePublishModel({
    required SDKPublishModel model,
    required bool isPreview,
  }) =>
      cacheManager.store(
        modelCacheKey(isPreview),
        model.toFullJson(),
      );

  /// Stores the given [bytes] of a [fontID] in the cache.
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

  /// Deletes a given layout associated with a [layoutID] from the cache.
  void deletePublishLayout({
    required String layoutID,
    required bool isPreview,
  }) =>
      cacheManager.delete(modelCacheKey(isPreview));

  /// Deletes a given api associated with a [apiId] from the cache.
  void deletePublishApi({
    required String apiId,
    required bool isPreview,
  }) =>
      cacheManager.delete(apisCacheKey(isPreview));

  /// Deletes a given api associated with a [apiId] from the cache.
  void deletePublishVariable({
    required String layoutId,
    required bool isPreview,
  }) =>
      cacheManager.delete(variableCacheKey(isPreview));

  /// Deletes the stored bytes of a given [fontID] from the cache.
  void deleteFontBytes({
    required String fontID,
    required bool isPreview,
  }) =>
      cacheManager.deleteBytes(fontsCacheKey(isPreview), fontID);
}
