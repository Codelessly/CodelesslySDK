// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print, unnecessary_type_check

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

// ignore: avoid_relative_lib_imports
import '../google_fonts_metadata.dart';

/// URL for Google Fonts's API.
const _googleFontsAPIJsonRawUrl =
    'https://www.googleapis.com/webfonts/v1/webfonts?key=';
const _googleFontsGithubUrlForFontList =
    'https://raw.githubusercontent.com/material-foundation/flutter-packages/main/packages/google_fonts/generator/families_supported';

/// Path to our output constants.dart file.
const _constantsFileName = '../google_fonts_metadata.dart';

const Map<String, String> variantMap = {
  '100': '100',
  '200': '200',
  '300': '300',
  'regular': '400',
  '500': '500',
  '600': '600',
  '700': '700',
  '800': '800',
  '900': '900',
  '100italic': '100i',
  '200italic': '200i',
  '300italic': '300i',
  'italic': '400i',
  '500italic': '500i',
  '600italic': '600i',
  '700italic': '700i',
  '800italic': '800i',
  '900italic': '900i',
};

class GoogleFontApiFontInfoRecord {
  String family;
  String category;
  String version;
  List<String> variants;
  List<String> subsets;
  Map<String, String> files;

  GoogleFontApiFontInfoRecord({
    required this.family,
    required this.category,
    required this.version,
    required this.variants,
    required this.subsets,
    required this.files,
  });
}

List<String> makeListOfStrings(List<dynamic>? dlist) {
  final slist = dlist?.map((d) => d as String).toList() ?? [];

  return slist;
}

Map<String, String> makeStringStringMap(Map<String, dynamic>? dmap) {
  final smap = dmap?.map((k, v) => MapEntry(k, v as String)) ?? {};

  return smap;
}

// ignore: long-method
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print help text and exit.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Print extra info during processing.',
    )
    ..addFlag(
      'legacylanguages',
      abbr: 'l',
      negatable: false,
      help:
          'Include only legacy languages included in the existing constants.dart. The array `googleFontLanguagesCompleteList` will be included with complete langauge list.',
    )
    ..addOption(
      'googlefontslist',
      abbr: 'g',
      defaultsTo: 'missing',
      help:
          'This argument should be followed by the path to the local file containing the list of fonts included within the current googlefonts package (the version specified within pubspec.yaml).  Generate this list using by running display_googlefonts_fontlist.dart within the samples directory and saving the font list to a local file within this directory.',
    )
    ..addOption(
      'inputjsonfile',
      abbr: 'i',
      defaultsTo: 'missing',
      help:
          'This argument should be followed by the path to the local file containing the google fonts api output json.',
    )
    ..addOption(
      'apikey',
      abbr: 'a',
      defaultsTo: 'missing',
      help:
          'This argument should be followed by your SECRET Google fonts api key.',
    );
  late final ArgResults results;

  try {
    results = parser.parse(args);
  } catch (e) {
    printUsage(parser);
    exit(0);
  }

  if (results['help'] as bool) {
    printUsage(parser);
    exit(0);
  }

  final legacyLanguageFlag = results['legacylanguages'] as bool;
  final verboseFlag = results['verbose'] as bool;
  final googleFontsListFile = results['googlefontslist'];
  final suppliedFontList = (googleFontsListFile != 'missing');
  final inputJsonFilename = results['inputjsonfile'];
  final localJson = (inputJsonFilename != 'missing');
  final googleFontAPIKey = results['apikey'];
  final apiKey = (googleFontAPIKey != 'missing');

  if (!localJson && !apiKey) {
    printUsage(parser);
    exit(0);
  }

  final List<String> googleFontsPackageFontList = [];
  if (!suppliedFontList) {
    print(
      'Attempting to retrieve current google_fonts font list from `$_googleFontsGithubUrlForFontList`',
    );

    final client = HttpClient();
    final request =
        await client.getUrl(Uri.parse(_googleFontsGithubUrlForFontList));
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      // Unexpected status returned.
      print(
        'Request to retrieve font list from $_googleFontsGithubUrlForFontList returned UNEXPECTED status code ${response.statusCode}',
      );
      print(
        'Because Automatic retreival of font list FAILED, and no list of fonts included on command line (--googlefontslist)',
      );
      print(
        'ALL FONTS output by the google fonts api will be included within constants.dart.',
      );
    } else {
      String rawFontListData = await response.transform(utf8.decoder).join();

      if (verboseFlag) {
        print(
          'Font list retrieved from _googleFontsGithubUrlForFontList:\n$rawFontListData',
        );
      }

      LineSplitter.split(rawFontListData).forEach(
        (line) {
          final fname = line.trim();
          if (fname.isNotEmpty) {
            googleFontsPackageFontList.add(fname);
          }
        },
      );
      print(
        'Read ${googleFontsPackageFontList.length} fonts from `$_googleFontsGithubUrlForFontList`',
      );
    }
  } else {
    try {
      // get the list
      final gflf = File(googleFontsListFile);
      List<String> lines = gflf.readAsLinesSync();
      for (final line in lines) {
        final fname = line.trim();
        if (fname.isNotEmpty) {
          googleFontsPackageFontList.add(fname);
        }
      }
      print(
        'Read ${googleFontsPackageFontList.length} fonts from $googleFontsListFile',
      );
    } catch (e) {
      print('Caught error reading $googleFontsListFile');
      print(e);
      exit(1);
    }
  }

  late final String apiJson;
  if (localJson) {
    print('Reading Google Fonts JSON from $inputJsonFilename');
    try {
      File localFile = File(inputJsonFilename);

      apiJson = localFile.readAsStringSync();
    } catch (e) {
      print(e.toString());
      exit(1);
    }
  } else if (apiKey) {
    print(
      'Querying Google Fonts API directly using Google Fonts APIKey $googleFontAPIKey',
    );

    final client = HttpClient();
    final request = await client
        .getUrl(Uri.parse(_googleFontsAPIJsonRawUrl + googleFontAPIKey));
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      // Unexpected status returned.
      print(
        'Request to ${_googleFontsAPIJsonRawUrl}XXX returned UNEXPECTED status code ${response.statusCode}',
      );
      exit(1);
    }
    apiJson = await response.transform(utf8.decoder).join();
  }

  /*  EXAMPLE head of API Json:
{
  "kind": "webfonts#webfontList",
  "items": [
    {
      "family": "ABeeZee",
      "variants": [
        "regular",
        "italic"
      ],
      "subsets": [
        "latin",
        "latin-ext"
      ],
      "version": "v22",
      "lastModified": "2022-09-22",
      "files": {
        "regular": "http://fonts.gstatic.com/s/abeezee/v22/esDR31xSG-6AGleN6tKukbcHCpE.ttf",
        "italic": "http://fonts.gstatic.com/s/abeezee/v22/esDT31xSG-6AGleN2tCklZUCGpG-GQ.ttf"
      },
      "category": "sans-serif",
      "kind": "webfonts#webfont"
    },
    {
      "family": "Abel",
      "variants": [
        "regular"
      ],
      "subsets": [
        "latin"
      ],
      "version": "v18",
      "lastModified": "2022-09-22",
      "files": {
        "regular": "http://fonts.gstatic.com/s/abel/v18/MwQ5bhbm2POE6VhLPJp6qGI.ttf"
      },
      "category": "sans-serif",
      "kind": "webfonts#webfont"
    },
    {
      "family": "Abhaya Libre",
      "variants": [
        "regular",
        "500",
        "600",
        "700",
        "800"
      ],
      "subsets": [
        "latin",
        "latin-ext",
        "sinhala"
      ],
      "version": "v13",
      "lastModified": "2022-09-22",
      "files": {
        "regular": "http://fonts.gstatic.com/s/abhayalibre/v13/e3tmeuGtX-Co5MNzeAOqinEge0PWovdU4w.ttf",
        "500": "http://fonts.gstatic.com/s/abhayalibre/v13/e3t5euGtX-Co5MNzeAOqinEYj2ryqtxI6oYtBA.ttf",
        "600": "http://fonts.gstatic.com/s/abhayalibre/v13/e3t5euGtX-Co5MNzeAOqinEYo23yqtxI6oYtBA.ttf",
        "700": "http://fonts.gstatic.com/s/abhayalibre/v13/e3t5euGtX-Co5MNzeAOqinEYx2zyqtxI6oYtBA.ttf",
        "800": "http://fonts.gstatic.com/s/abhayalibre/v13/e3t5euGtX-Co5MNzeAOqinEY22_yqtxI6oYtBA.ttf"
      },
      "category": "serif",
      "kind": "webfonts#webfont"
    },
    ......
    */

  final Map<String, dynamic> apiJsonObj = jsonDecode(apiJson);

  assert(apiJsonObj is Map);
  assert(apiJsonObj['kind'] == 'webfonts#webfontList');
  assert(apiJsonObj['items'] is List);

  final List fontItems = apiJsonObj['items'];

  print(
    'Items list in google fonts api json includes ${fontItems.length} fonts',
  );

  final Map<String, GoogleFontApiFontInfoRecord> fontMap = {};
  final List<String> allEncountedCategories = [];
  final List<String> allEncountedLanguageSubsets = [];
  final List<String> unknownUnMappedVariants = [];

  // keep track of new and removed fonts and categories
  final List<String> newFonts = [];
  final List<String> removedFonts = [];
  final List<String> newCategories = [];
  final List<String> removedCategories = [];
  final List<String> newLanguageSubsets = [];
  final List<String> removedLanguageSubsets = [];

  if (googleFontsPackageFontList.isEmpty) {
    print('No font list supplied, dumping info for ALL fonts');
  }

  var skippedFonts = 0;

  // Make lookup map
  for (final item in fontItems) {
    final family = item['family'];
    final subsets = makeListOfStrings(item['subsets']);
    final variants = makeListOfStrings(item['variants']);
    final files = makeStringStringMap(item['files']);
    bool includeFont = googleFontsPackageFontList.isEmpty ||
        googleFontsPackageFontList.contains(family);

    if (includeFont && family.isNotEmpty) {
      final category = item['category'] ?? '';
      if (category.isNotEmpty && !allEncountedCategories.contains(category)) {
        allEncountedCategories.add(category);

        // detect categories which were not in previous version
        if (!googleFontCategories.contains(category)) {
          newCategories.add(category);
        }
      }
      if (!googleFontsList.contains(family)) {
        newFonts.add(family);
      }
      // make sure the subsets array is sorted
      subsets.sort();
      for (final subset in subsets) {
        if (!allEncountedLanguageSubsets.contains(subset)) {
          allEncountedLanguageSubsets.add(subset);
          if (!googleFontLanguages.contains(subset)) {
            newLanguageSubsets.add(subset);
          }
        }
      }
      final List<String> remappedVariants = [];
      for (final variant in variants) {
        if (!variantMap.containsKey(variant)) {
          unknownUnMappedVariants.add(variant);

          print(
            'ERROR: UNKNOWN and UNMAPPED variants were encountered:  $variant in font $family',
          );
        } else {
          remappedVariants.add(variantMap[variant]!);
        }
      }
      // make sure variants are sorted
      remappedVariants.sort();

      fontMap[family] = GoogleFontApiFontInfoRecord(
        family: family,
        category: category,
        version: item['version'] ?? '',
        subsets: subsets,
        variants: remappedVariants,
        files: files,
      );
    } else {
      skippedFonts++;
    }
  }

  // Sort arrays we want sorted
  allEncountedLanguageSubsets.sort();
  if (verboseFlag) {
    print('allEncountedLanguageSubsets = $allEncountedLanguageSubsets');
  }

  // get sorted list of font keys
  final sortedFontMapFonts = fontMap.keys.toList()..sort();

  // NOTE: this SHOULD NEVER HAPPEN because it would imply that there were new font
  // weight constants that need to be added to flutter itself..  But just to be thorough
  // and check all possible errors...
  if (unknownUnMappedVariants.isNotEmpty) {
    print('ERROR: Unexpected, UNKNOWN and UNMAPPED variants were encountered.');
    print(unknownUnMappedVariants);
    print(
      'Please update the `variantMap` constant map within update_constants.dart',
    );
    print(
      'and the `fontWeightValues` array within lib\\src\\constants\\fontweight_map.dart ',
    );
    exit(1);
  }

  // Now look the other direction to find *removed* categories and fonts
  for (final category in googleFontCategories) {
    // detect categories which were in previous version BUT NOT in this version
    if (!allEncountedCategories.contains(category)) {
      removedCategories.add(category);
    }
  }
  for (final subset in googleFontLanguages) {
    if (!allEncountedLanguageSubsets.contains(subset)) {
      removedLanguageSubsets.add(subset);
    }
  }

  for (final family in googleFontsList) {
    // detect categories which were in previous version BUT NOT in this version
    if (!fontMap.containsKey(family)) {
      removedFonts.add(family);
    }
  }

  // Display summary info of whats been found/changes from previous version.
  print(
    '${allEncountedCategories.length} categories found - ${newCategories.length} new categories detected:',
  );
  if (verboseFlag) print('$newCategories');
  if (removedCategories.isNotEmpty) {
    print('${removedCategories.length} removed categories:');
    print('$removedCategories');
  }
  if (!legacyLanguageFlag) {
    print(
      '${allEncountedLanguageSubsets.length} language subsets found - ${newLanguageSubsets.length} new language subsets detected:',
    );
    if (verboseFlag) print('$newLanguageSubsets');
    if (removedLanguageSubsets.isNotEmpty) {
      print('${removedLanguageSubsets.length} removed language subsets:');
      print('$removedLanguageSubsets');
    }
  } else {
    print(
      'The --legacylanguages flag has been specified and only legacy languages from',
    );
    print('existing constants.dart will be included.');
  }
  print(
    '${fontMap.length} fonts found - ${newFonts.length} new fonts detected:',
  );
  if (verboseFlag) print('$newFonts');
  if (removedFonts.isNotEmpty) {
    print('${removedFonts.length} removed fonts:');
    print('$removedFonts');
  }

  print('Including ${fontMap.length} fonts in output constants.dart');
  if (googleFontsPackageFontList.isEmpty) {
    print(
      'No googlefonts package font list was supplied so including all fonts from API json.',
    );
  } else {
    print(
      'Skipped $skippedFonts that were not included in the supplied googlefonts package font list.',
    );
  }

  // Write out constants.dart file here
  final constantsContent = StringBuffer('''
// GENERATED FILE. DO NOT EDIT.
//
// This file was generated from a combination of the GoogleFonts package
// version specified in pubspec.yaml and information contained in the json file
// returned by the GoogleFonts API font information endpoint.
// See https://developers.google.com/fonts/docs/developer_api 
// This file was generated at ${DateTime.now()} by the dart file
// `update_google_fonts_metadata.dart`.
''');
  constantsContent.writeln();

  // write googleFontCategories[] array in order of previous array
  constantsContent.writeln('const googleFontCategories = [');
  for (final category in googleFontCategories) {
    constantsContent.writeln("\t'$category',");
  }
  // and add any new categories
  for (final category in newCategories) {
    constantsContent.writeln("\t'$category',");
  }
  constantsContent.writeln('];');
  constantsContent.writeln();

  constantsContent.writeln('const googleFontLanguages = [');
  if (legacyLanguageFlag) {
    for (final language in googleFontLanguages) {
      constantsContent.writeln("\t'$language',");
    }
    constantsContent.writeln('];');
    constantsContent.writeln();
    constantsContent.writeln('const googleFontLanguagesCompleteList = [');
  }
  // Now write the complete language list.
  // This is OUR special category for flutter_font_picker:
  constantsContent.writeln("\t'all',");
  for (final language in allEncountedLanguageSubsets) {
    constantsContent.writeln("\t'$language',");
  }
  constantsContent.writeln('];');
  constantsContent.writeln();

  constantsContent.writeln('const googleFontsList = [');
  for (final fontfamily in sortedFontMapFonts) {
    constantsContent.writeln("\t'$fontfamily',");
  }
  constantsContent.writeln('];');
  constantsContent.writeln();

  constantsContent.writeln('const googleFontsDetails = {');
  for (final fontfamily in sortedFontMapFonts) {
    if (!fontMap.containsKey(fontfamily)) {
      print('Unexpected FATAL ERROR : $fontfamily not font in `fontMap`');
      exit(1);
    }
    final fontinfo = fontMap[fontfamily]!;
    final variantListStr = fontinfo.variants.join(',');
    final subsetsListStr = fontinfo.subsets.join(',');

    int lineLen = 47 +
        fontfamily.length +
        fontinfo.category.length +
        variantListStr.length +
        subsetsListStr.length;
    if (lineLen < 80) {
      constantsContent.writeln(
        '\t\'$fontfamily\': {\'category\': \'${fontinfo.category}\', \'variants\': \'$variantListStr\', \'subsets\': \'$subsetsListStr\',},',
      );
    } else {
      constantsContent.writeln('\t\'$fontfamily\': {');
      constantsContent.writeln('\t\t\'category\': \'${fontinfo.category}\',');
      if (variantListStr.length > 60) {
        constantsContent.writeln('\t\t\'variants\':');
        constantsContent.writeln('\t\t\t\t\'$variantListStr\',');
      } else {
        constantsContent.writeln('\t\t\'variants\': \'$variantListStr\',');
      }
      if (subsetsListStr.length > 60) {
        constantsContent.writeln('\t\t\'subsets\':');
        constantsContent.writeln('\t\t\t\t\'$subsetsListStr\',');
      } else {
        constantsContent.writeln('\t\t\'subsets\': \'$subsetsListStr\',');
      }
      constantsContent.writeln('\t},');
    }
  }
  constantsContent.writeln('};');

  File(_constantsFileName).writeAsStringSync(constantsContent.toString());

  print('Wrote data to $_constantsFileName');
  exit(0);
}

void printUsage(ArgParser parser) {
  print(
    '''Usage: update_constants.dart [[--googlefontslist | -g] filenamecontaininglist.txt] [[--inputjsonfile | -i] api_output.json] | [[--apikey | -a] YOUR_SECRET_GOOGLE_FONT_API_KEY]
The list of fonts included in the current GoogleFonts package should be generated using the 
`display_googlefonts_fontlist.dart` program included within the `examples` subdirectory.
(GoogleFonts is a flutter package so the list cannot be automatically generated here).
Run the `display_googlefonts_fontlist.dart` program and copy the list of fonts provided and
save them into a local file within this directory.
This file is then supplied on the command line using the --googlefontslist (or -g) directive.
If the font list is NOT supplied then all fonts include within the googlefonts API Json will be
included within the output constants.dart (including those not available from the
current googlefonts package).
The google fonts API JSON can be supplied one of two ways:
1) Using a local file that contains the output of the google fonts api generated at
https://developers.google.com/fonts/docs/developer_api and saved in a local file.
The --inputjsonfile (or -i) and flag is then used with the name of the local file containing
the output from clicking the 'EXECUTE' button on the google fonts developer page above.
2) The second method is to supply your private (secret) google fonts api key on the
command line using the --apikey (or -a) argument followed by your secret key.  This method
directly queries the google fonts API and retreives the JSON file.
${parser.usage}
''',
  );
}
