import 'package:codelessly_api/codelessly_api.dart';

/// First-party static icon CDN root; override for a self-hosted mirror with
/// --dart-define=CODELESSLY_CUPERTINO_SVG_BASE_URL=https://icons.example.com.
const String cupertinoSvgBaseUrl = String.fromEnvironment(
  'CODELESSLY_CUPERTINO_SVG_BASE_URL',
  defaultValue: 'https://icons.codelessly.com',
);

/// Version of the pinned cupertino_icons font used by the SVG exporter.
const String cupertinoSvgVersion = '1.0.9';

/// Stable path based on the serialized Cupertino codepoint, not an icon name.
String? cupertinoSvgUrl(
  CupertinoIcon icon, {
  String baseUrl = cupertinoSvgBaseUrl,
}) {
  if (baseUrl.isEmpty || icon.codepoint <= 0) return null;
  final root = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return '$root/cupertino/$cupertinoSvgVersion/${icon.codepoint.toRadixString(16)}.svg';
}
