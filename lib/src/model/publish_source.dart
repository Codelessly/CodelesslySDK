import '../../codelessly_sdk.dart';

enum PublishSource {
  publish,
  preview,
  template;

  bool get isPublish => this == PublishSource.publish;

  bool get isPreview => this == PublishSource.preview;

  bool get isTemplate => this == PublishSource.template;

  String get serverPath => switch (this) {
        PublishSource.publish => publishPath,
        PublishSource.preview => previewPath,
        PublishSource.template => templatesPath,
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
