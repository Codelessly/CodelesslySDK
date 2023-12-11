import '../../codelessly_sdk.dart';

/// Defines the server-sided source a publish model should be retrieved from.
enum PublishSource {
  /// The publish collection.
  publish,

  /// The previews collection.
  preview,

  /// The templates collection.
  template;

  /// Whether this is the publish collection.
  bool get isPublish => this == PublishSource.publish;

  /// Whether this is the previews collection.
  bool get isPreview => this == PublishSource.preview;

  /// Whether this is the templates collection.
  bool get isTemplate => this == PublishSource.template;

  /// The path to the data collection.
  String get rootDataCollection => switch (this) {
        PublishSource.publish => 'data',
        PublishSource.preview => 'preview_data',
        PublishSource.template => 'template_data',
      };

  /// The path to the publish model collection.
  String get serverPath => switch (this) {
        PublishSource.publish => publishPath,
        PublishSource.preview => previewPath,
        PublishSource.template => templatesPath,
      };

  /// The path to the mirrored or opposite collection.
  String get mirroredServerPath => switch (this) {
        PublishSource.publish => previewPath,
        PublishSource.preview => publishPath,
        PublishSource.template => publishPath,
      };

  /// The cache key for the published model.
  String get modelCacheKey => switch (this) {
        PublishSource.publish => publishModelCacheKey,
        PublishSource.preview => previewModelCacheKey,
        PublishSource.template => templateModelCacheKey,
      };

  /// The cache key for the font files.
  String get fontsCacheKey => switch (this) {
        PublishSource.publish => publishFontsCacheKey,
        PublishSource.preview => previewFontsCacheKey,
        PublishSource.template => templateFontsCacheKey,
      };

  /// The cache key for the APIs.
  String get apisCacheKey => switch (this) {
        PublishSource.publish => publishApisCacheKey,
        PublishSource.preview => previewApisCacheKey,
        PublishSource.template => templateApisCacheKey,
      };

  /// The cache key for the APIs.
  String get variablesCacheKey => switch (this) {
        PublishSource.publish => publishVariablesCacheKey,
        PublishSource.preview => previewVariablesCacheKey,
        PublishSource.template => templateVariablesCacheKey,
      };

  /// The cache key for the APIs.
  String get conditionsCacheKey => switch (this) {
        PublishSource.publish => publishConditionsCacheKey,
        PublishSource.preview => previewConditionsCacheKey,
        PublishSource.template => templateConditionsCacheKey,
      };
}
