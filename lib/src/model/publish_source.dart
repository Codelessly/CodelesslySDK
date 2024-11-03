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
        PublishSource.publish => 'publish',
        PublishSource.preview => 'publish_preview',
        PublishSource.template => 'templates',
      };

  /// The path to the mirrored or opposite collection.
  String get mirroredServerPath => switch (this) {
        PublishSource.publish => 'publish_preview',
        PublishSource.preview => 'publish',
        PublishSource.template => 'publish',
      };

  /// The cache key for the published model.
  String get modelCacheKey => switch (this) {
        PublishSource.publish => 'publish_layout_model',
        PublishSource.preview => 'preview_layout_model',
        PublishSource.template => 'template_layout_model',
      };

  /// The cache key for the font files.
  String get fontsCacheKey => switch (this) {
        PublishSource.publish => 'publish_fonts',
        PublishSource.preview => 'preview_fonts',
        PublishSource.template => 'template_fonts',
      };

  /// The cache key for the APIs.
  String get apisCacheKey => switch (this) {
        PublishSource.publish => 'publish_apis',
        PublishSource.preview => 'preview_apis',
        PublishSource.template => 'template_apis',
      };

  /// The cache key for the APIs.
  String get variablesCacheKey => switch (this) {
        PublishSource.publish => 'publish_variables',
        PublishSource.preview => 'preview_variables',
        PublishSource.template => 'template_variables',
      };

  /// The cache key for the APIs.
  String get conditionsCacheKey => switch (this) {
        PublishSource.publish => 'publish_conditions',
        PublishSource.preview => 'preview_conditions',
        PublishSource.template => 'template_conditions',
      };
}
