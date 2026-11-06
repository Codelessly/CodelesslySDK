import 'dart:convert';

import '../catalog/catalog_spec.dart';

/// The name of the tool the agent calls to render UI.
const String kRenderToolName = 'render_ui';

/// The render tool's description.
const String kRenderToolDescription =
    'Render interactive UI inline in the chat by sending A2UI v0.9.1 '
    'messages for the Codelessly GenUI catalog. The result reports '
    'validation problems; if there are any, call the tool again with the '
    'fixed, complete messages for the same surfaceId.';

/// The render tool's input schema: a list of A2UI server-to-client
/// messages. The component schemas are in the catalog document the system
/// prompt carries, which keeps the tool schema small.
Map<String, Object?> renderToolInputSchema() => {
  'type': 'object',
  'properties': {
    'messages': {
      'type': 'array',
      'description':
          'A2UI messages in order: createSurface, updateDataModel, '
          'updateComponents (and later updates or deleteSurface).',
      'items': {
        'type': 'object',
        'properties': {
          'version': {'const': kGenUiProtocolVersion.jsonValue},
          'createSurface': {'type': 'object'},
          'updateComponents': {'type': 'object'},
          'updateDataModel': {'type': 'object'},
          'deleteSurface': {'type': 'object'},
        },
        'required': ['version'],
      },
    },
  },
  'required': ['messages'],
};

/// The catalog document, compacted for a prompt: descriptions kept,
/// `$schema` and ids dropped.
String compactCatalogJson() {
  final Map<String, Object?> catalog = buildGenUiCatalogJson();
  return jsonEncode({
    'catalogId': catalog['catalogId'],
    'components': catalog['components'],
    'functions': catalog['functions'],
    r'$defs': catalog[r'$defs'],
  });
}

/// The system prompt for a chat agent that renders with this catalog.
///
/// [extra] is the host's own guidance (persona, domain notes), placed
/// before the catalog.
String genUiSystemPrompt({String extra = ''}) =>
    '''
You are a helpful assistant in a chat that can show interactive UI inline. Answer in short prose, and when a form, a choice, a calculator, a chart or any explorable visualization would help, call the $kRenderToolName tool. Write your prose first (one to three sentences), then call $kRenderToolName once, as the last thing in your reply, with every message the UI needs.

$kGenUiCatalogInstructions
Protocol (A2UI v0.9.1, https://a2ui.org):
- Message shapes:
  {"version":"v0.9.1","createSurface":{"surfaceId":"s1","catalogId":"$kGenUiCatalogId","sendDataModel":true,"theme":{"primaryColor":"#3D5AFE"}}}
  {"version":"v0.9.1","updateDataModel":{"surfaceId":"s1","path":"/","value":{...}}}
  {"version":"v0.9.1","updateComponents":{"surfaceId":"s1","components":[{"id":"root","component":"Column","children":["a","b"]}, ...]}}
  {"version":"v0.9.1","deleteSurface":{"surfaceId":"s1"}}
- Dynamic values: a literal, {"path":"/json/pointer"}, or {"call":"name","args":{...},"returnType":"string"}. formatString interpolates "\${/path}" and "\${calc(expr:'a*b')}".
- Children: ["id1","id2"] or a template {"componentId":"rowTpl","path":"/items"}; inside a template, paths without a leading "/" are relative to the item.
- Actions: {"event":{"name":"submit","context":{"email":{"path":"/email"}}}}.
- To change an existing surface later, send updateDataModel or updateComponents for its surfaceId; do not create it again.
- surfaceId must be unique in the conversation (s1, s2, ...).

When the user interacts, you receive a user turn holding an A2UI action message and the surface data model, e.g.
{"version":"v0.9.1","action":{"name":"weight_changed","surfaceId":"s1","sourceComponentId":"weight","context":{...}}}
{"a2uiClientDataModel":{...}}
React to it in one or two sentences about the new values; update the surface only if something must change that formulas cannot compute.

$extra
Catalog (JSON Schema; component names and properties must match exactly):
${compactCatalogJson()}
''';
