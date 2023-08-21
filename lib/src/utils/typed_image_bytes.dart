import 'dart:typed_data';

import 'package:path/path.dart' as path;

/// Represents the type of a resource. It can represent file, url or bytes
/// that correspond to one of the supported types.
enum ResourceType {
  svg,
  png,
  jpg,
  gif,
  webp,
  unknown;

  bool get isSvg => this == ResourceType.svg;

  bool get isPng => this == ResourceType.png;

  bool get isJpg => this == ResourceType.jpg;

  bool get isGif => this == ResourceType.gif;

  bool get isWebp => this == ResourceType.webp;

  bool get isStandardImage => isPng || isJpg || isWebp;

  factory ResourceType.fromExtension(String type) => switch (type) {
        'svg' || '.svg' => ResourceType.svg,
        'png' || '.png' => ResourceType.png,
        'jpg' || '.jpg' || 'jpeg' || '.jpeg' => ResourceType.jpg,
        'gif' || '.gif' => ResourceType.gif,
        'webp' || '.webp' => ResourceType.webp,
        _ => ResourceType.unknown,
      };

  factory ResourceType.fromUrl(String url) =>
      ResourceType.fromExtension(path.extension(Uri.parse(url).path));

  factory ResourceType.fromFilePath(String filePath) =>
      ResourceType.fromExtension(path.extension(filePath));
}

/// Allows to carry information about the type of bytes. This is useful when
/// decoding is required and the type of bytes is necessary to know how to
/// decode them.
typedef TypedBytes = ({Uint8List bytes, ResourceType type});
