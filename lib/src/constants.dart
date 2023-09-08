const String defaultFirebaseProjectId = String.fromEnvironment(
  'firebase_project_id',
  defaultValue: prodFirebaseProjectId,
);

const String defaultFirebaseCloudFunctionsBaseURL = String.fromEnvironment(
  'cloud_functions_base_url',
  defaultValue: prodFirebaseCloudFunctionsBaseURL,
);

const String defaultBaseURL = String.fromEnvironment(
  'base_url',
  defaultValue: prodBaseUrl,
);

const String prodFirebaseProjectId = 'codeless-app';
const String prodFirebaseCloudFunctionsBaseURL =
    'https://us-central1-codeless-app.cloudfunctions.net';

const String prodBaseUrl = 'https://app.codelessly.com';

const defaultErrorMessage =
    'We encountered some error while rendering this page! '
    'We are working on it to fix it as soon as possible.';

const String cacheBoxName = 'cache';
const String cacheFilesBoxName = 'cache_files';
const String authCacheKey = 'auth';

const String publishModelCacheKey = 'publish_layout_model';
const String previewModelCacheKey = 'preview_layout_model';
const String templateModelCacheKey = 'template_layout_model';

const String publishFontsCacheKey = 'publish_fonts';
const String previewFontsCacheKey = 'preview_fonts';
const String templateFontsCacheKey = 'template_fonts';

const String publishApisCacheKey = 'publish_apis';
const String previewApisCacheKey = 'preview_apis';
const String templateApisCacheKey = 'template_apis';

const String publishVariablesCacheKey = 'publish_variables';
const String previewVariablesCacheKey = 'preview_variables';
const String templateVariablesCacheKey = 'template_variables';

const String publishConditionsCacheKey = 'publish_conditions';
const String previewConditionsCacheKey = 'preview_conditions';
const String templateConditionsCacheKey = 'template_conditions';

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
