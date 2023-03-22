import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class FontFileData extends Equatable {
  final String fileName;
  final String fileExtension;
  final String familyName;
  final String style;
  final Uint8List bytes;

  FontFileData({
    required this.fileName,
    required this.fileExtension,
    required this.familyName,
    required this.style,
    required this.bytes,
  });

  @override
  List<Object?> get props =>
      [fileName, fileExtension, familyName, style, bytes];
}
