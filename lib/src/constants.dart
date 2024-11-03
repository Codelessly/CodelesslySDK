/// The unique identifier for the Codelessly Firebase app instance.
const String kCodelesslyFirebaseApp = 'codelessly';

/// Production environment constants
const String kProdFirebaseProjectId = 'codeless-app';
const String kProdCloudFunctionsBaseURL =
    'https://us-central1-codeless-app.cloudfunctions.net';
const String kProdBaseURL = 'https://app.codelessly.com';

/// Editor identifier constant
const String kCodelesslyEditor = 'codelessly_editor';

/// Default error message for rendering failures
const String defaultErrorMessage = 'Error rendering page.';

/// Cache-related constants
const String cacheBoxName = 'cache';
const String cacheFilesBoxName = 'cache_files';
const String authCacheKey = 'auth';

/// Model cache keys
const String publishModelCacheKey = 'publish_layout_model';
const String previewModelCacheKey = 'preview_layout_model';
const String templateModelCacheKey = 'template_layout_model';

/// Font cache keys
const String publishFontsCacheKey = 'publish_fonts';
const String previewFontsCacheKey = 'preview_fonts';
const String templateFontsCacheKey = 'template_fonts';

/// API cache keys
const String publishApisCacheKey = 'publish_apis';
const String previewApisCacheKey = 'preview_apis';
const String templateApisCacheKey = 'template_apis';

/// Variable cache keys
const String publishVariablesCacheKey = 'publish_variables';
const String previewVariablesCacheKey = 'preview_variables';
const String templateVariablesCacheKey = 'template_variables';

/// Condition cache keys
const String publishConditionsCacheKey = 'publish_conditions';
const String previewConditionsCacheKey = 'preview_conditions';
const String templateConditionsCacheKey = 'template_conditions';

/// Path constants
const String publishPath = 'publish';
const String previewPath = 'publish_preview';
const String templatesPath = 'templates';

/// The template url for the svg icons.
/// {{style}}: The style of the icon. e.g. materialiconsoutlined
/// {{name}}: The name of the icon. e.g. home
/// {{version}}: The version of the icon. e.g. 16
/// {{size}}: The size of the icon. e.g. 24
const String kSvgIconBaseUrlTemplate =
    'https://fonts.gstatic.com/s/i/{{style}}/{{name}}/v{{version}}/{{size}}px.svg';
