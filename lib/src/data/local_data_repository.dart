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

  /// Returns the [SDKPublishModel] from the cache.
  SDKPublishModel? fetchPublishModel({
    required PublishSource source,
  }) {
    try {
      return cacheManager.get(
        source.modelCacheKey,
        decode: SDKPublishModel.fromJson,
      );
    } catch (e) {
      return null;
    }
  }

  /// Returns the [SDKPublishLayout] from the cache.
  Uint8List? fetchFontBytes({
    required String fontID,
    required PublishSource source,
  }) {
    try {
      return cacheManager.getBytes(source.fontsCacheKey, fontID);
    } catch (e) {
      return null;
    }
  }

  /// Stores the [SDKPublishModel] in the cache.
  Future<void> savePublishModel({
    required SDKPublishModel model,
    required PublishSource source,
  }) =>
      cacheManager.store(
        source.modelCacheKey,
        model.toFullJson(),
      );

  /// Stores the given [bytes] of a [fontID] in the cache.
  Future<void> saveFontBytes({
    required String fontID,
    required Uint8List bytes,
    required PublishSource source,
  }) =>
      cacheManager
          .storeBytes(
        source.fontsCacheKey,
        fontID,
        bytes,
      )
          .catchError((e, str) {
        debugPrintStack(label: '$e', stackTrace: str);
      });

  /// Deletes a given layout associated with a [layoutID] from the cache.
  void deletePublishLayout({
    required String layoutID,
    required PublishSource source,
  }) =>
      cacheManager.delete(source.modelCacheKey);

  /// Deletes a given api associated with a [apiId] from the cache.
  void deletePublishApi({
    required String apiId,
    required PublishSource source,
  }) =>
      cacheManager.delete(source.apisCacheKey);

  /// Deletes a given api associated with a [apiId] from the cache.
  void deletePublishVariables({
    required String docID,
    required PublishSource source,
  }) =>
      cacheManager.delete(source.variablesCacheKey);

  /// Deletes a given api associated with a [apiId] from the cache.
  void deletePublishConditions({
    required String docID,
    required PublishSource source,
  }) =>
      cacheManager.delete(source.conditionsCacheKey);

  /// Deletes the stored bytes of a given [fontID] from the cache.
  void deleteFontBytes({
    required String fontID,
    required PublishSource source,
  }) =>
      cacheManager.deleteBytes(source.fontsCacheKey, fontID);
}
