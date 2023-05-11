import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart';

void main(List<String> args) {
  final file = File(args[0]);
  final result = FontParser.parse(file.readAsBytesSync());
  print('Result: ${JsonEncoder.withIndent('  ').convert(result)}');
}

/// Compares the given [a] [FontVariantModel] with the [b] [FontVariantModel]
/// and returns the score.
///
/// The score is the sum of the absolute difference of the [FontWeight] and
/// the [FontStyle] of the two [FontVariantModel]s.
///
/// The lower the score, the closer the match.
///
/// [returns] The score of the match.
int _computeMatch(FontVariantModel a, FontVariantModel b) {
  if (a == b) {
    return 0;
  }
  int score = (a.weight.index - b.weight.index).abs();
  if (a.style != b.style) {
    score += 2;
  }
  return score;
}

/// [returns] The closest matching [FontVariantModel] from [variantsToCompare]
/// to the given [sourceVariant].
///
/// The [FontVariantModel] with the lowest score is returned.
FontVariantModel _closestMatch(FontVariantModel sourceVariant,
    Iterable<FontVariantModel> variantsToCompare) {
  int? bestScore;
  late FontVariantModel bestMatch;
  for (final variantToCompare in variantsToCompare) {
    final int score = _computeMatch(sourceVariant, variantToCompare);
    if (bestScore == null || score < bestScore) {
      bestScore = score;
      bestMatch = variantToCompare;
    }
  }
  return bestMatch;
}

/// [returns] The Flutter-usable font family name for the given [fontName].
String getFontFamilyNameAndVariant(
  FontName fontName, {
  FontFamilyModel? familyModel,
}) {
  FontWeightNumeric weight = fontName.weight ?? FontWeightNumeric.w400;
  String family = fontName.family;
  String style =
      fontName.style.toLowerCase().contains('italic') ? 'Italic' : 'Normal';

  if (familyModel != null) {
    /// familyModel is not null then this is running from the IDE. In this case,
    /// we need to derive the font family name from the font variants.
    // final FontVariantModel bestMatchedVariant = _closestMatch(
    //   FontVariantModel(
    //     weight: weight,
    //     style: style,
    //   ),
    //   familyModel.fontVariants,
    // );
    // print('Best matched variant for family $family: ${bestMatchedVariant.name} | ${bestMatchedVariant.style} | ${bestMatchedVariant.weight}');
    return deriveFontFamily(
      family: family,
      weight: weight,
      style: fontName.style,
    );
  }
  // familyModel is null then this is running from the SDK. In this case,
  // we don't need to derive the font family name since it is already processed.
  return deriveFontFamily(
    family: family,
    style: style,
    weight: weight,
  );
}

String deriveFontFamily({
  required String family,
  required String style,
  required FontWeightNumeric? weight,
}) {
  switch (weight) {
    case FontWeightNumeric.w100:
      family = '$family Thin';
      break;
    case FontWeightNumeric.w200:
      family = '$family Extra Light';
      break;
    case FontWeightNumeric.w300:
      family = '$family Light';
      break;
    case FontWeightNumeric.w400:
      family = '$family Regular';
      break;
    case FontWeightNumeric.w500:
      family = '$family Medium';
      break;
    case FontWeightNumeric.w600:
      family = '$family Semibold';
      break;
    case FontWeightNumeric.w700:
      family = '$family Bold';
      break;
    case FontWeightNumeric.w800:
      family = '$family Extra Bold';
      break;
    case FontWeightNumeric.w900:
      family = '$family Black';
      break;
    default:
      break;
  }

  if (style == 'Italic' || style == 'Oblique') {
    family = '$family $style';
  }

  return family;
}

class FontNameBin {
  static final FontNameBin instance = FontNameBin();

  int readUshort(List<int> buff, int p) => (buff[p] << 8) | buff[p + 1];

  int readUint(List<int> buff, int p) {
    var a = uint8;
    a[3] = buff[p];
    a[2] = buff[p + 1];
    a[1] = buff[p + 2];
    a[0] = buff[p + 3];
    return uint32[0];
  }

  int readUint64(List<int> buff, int p) =>
      (readUint(buff, p) * (0xffffffff + 1) + readUint(buff, p + 4));

  /// [l] length in Characters (not Bytes)
  String readASCII(List<int> buff, int p, int l) {
    var s = '';
    for (var i = 0; i < l; i++) {
      s += String.fromCharCode(buff[p + i]);
    }
    return s;
  }

  String readUnicode(List<int> buff, int p, int l) {
    var s = '';
    for (var i = 0; i < l; i++) {
      var c = (buff[p++] << 8) | buff[p++];
      s += String.fromCharCode(c);
    }
    return s;
  }

  // t = { buff: new ArrayBuffer(8) };
  late ByteBuffer buff = ByteData(8).buffer;
  late Int8List int8 = buff.asInt8List();
  late Uint8List uint8 = buff.asUint8List();
  late Int16List int16 = buff.asInt16List();
  late Uint16List uint16 = buff.asUint16List();
  late Int32List int32 = buff.asInt32List();
  late Uint32List uint32 = buff.asUint32List();
}

class FontParser {
  static List<Map<String, dynamic>> parse(List<int> buff) {
    var bin = FontNameBin.instance;
    var data = Uint8List.fromList(buff);
    var tag = bin.readASCII(data, 0, 4);

    // If the file is a TrueType Collection
    if (tag == 'ttcf') {
      var offset = 8;
      var numF = bin.readUint(data, offset);
      offset += 4;
      var fnts = <Map<String, dynamic>>[];
      for (var i = 0; i < numF; i++) {
        var foff = bin.readUint(data, offset);
        offset += 4;
        fnts.add(_readFont(data, foff));
      }
      return fnts;
    } else {
      return [_readFont(data, 0)];
    }
  }

  static Map<String, dynamic> _readFont(Uint8List data, int offset) {
    var bin = FontNameBin.instance;

    offset += 4;
    var numTables = bin.readUshort(data, offset);
    offset += 8;

    for (var i = 0; i < numTables; i++) {
      var tag = bin.readASCII(data, offset, 4);
      offset += 8;
      var toffset = bin.readUint(data, offset);
      offset += 8;
      if (tag == 'name') {
        return parseName(data, toffset);
      }
    }

    throw Exception('Failed to parse file');
  }

  static Map<String, dynamic> parseName(Uint8List data, int offset) {
    FontNameBin bin = FontNameBin.instance;
    Map<String, dynamic> obj = {};
    offset += 2;
    int count = bin.readUshort(data, offset);
    offset += 2;
    offset += 2;

    List<String> names = [
      'copyright',
      'fontFamily',
      'fontSubfamily',
      'ID',
      'fullName',
      'version',
      'postScriptName',
      'trademark',
      'manufacturer',
      'designer',
      'description',
      'urlVendor',
      'urlDesigner',
      'licence',
      'licenceURL',
      '---',
      'typoFamilyName',
      'typoSubfamilyName',
      'compatibleFull',
      'sampleText',
      'postScriptCID',
      'wwsFamilyName',
      'wwsSubfamilyName',
      'lightPalette',
      'darkPalette'
    ];

    var offset0 = offset;

    for (var i = 0; i < count; i++) {
      var platformID = bin.readUshort(data, offset);
      offset += 2;
      var encodingID = bin.readUshort(data, offset);
      offset += 2;
      var languageID = bin.readUshort(data, offset);
      offset += 2;
      var nameID = bin.readUshort(data, offset);
      offset += 2;
      var slen = bin.readUshort(data, offset);
      offset += 2;
      var noffset = bin.readUshort(data, offset);
      offset += 2;

      if (nameID >= names.length) continue;

      var cname = names[nameID];
      var soff = offset0 + count * 12 + noffset;
      String str;
      if (platformID == 0) {
        str = bin.readUnicode(data, soff, slen ~/ 2);
      } else if (platformID == 3 && encodingID == 0) {
        str = bin.readUnicode(data, soff, slen ~/ 2);
      } else if (encodingID == 0) {
        str = bin.readASCII(data, soff, slen);
      } else if (encodingID == 1) {
        str = bin.readUnicode(data, soff, slen ~/ 2);
      } else if (encodingID == 3) {
        str = bin.readUnicode(data, soff, slen ~/ 2);
      } else if (platformID == 1) {
        str = bin.readASCII(data, soff, slen);
        print('reading unknown MAC encoding $encodingID as ASCII');
      } else {
        throw Exception(
            'unknown encoding $encodingID, platformID: $platformID');
      }

      var tid = 'p$platformID,${languageID.toRadixString(16)}';
      if (obj[tid] == null) {
        obj[tid] = {};
      }
      obj[tid][cname] = str;
      obj[tid]['_lang'] = languageID;
    }

    for (var p in obj.keys) {
      if (obj[p]['postScriptName'] != null) {
        return Map<String, dynamic>.from(obj[p]);
      }
    }

    // ignore: prefer_typing_uninitialized_variables
    var tname;
    for (var p in obj.keys) {
      tname = p;
      break;
    }
    print(obj);
    return obj[tname];
  }
}
