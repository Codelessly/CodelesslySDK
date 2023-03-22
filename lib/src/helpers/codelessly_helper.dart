import 'package:codelessly_api/api.dart';
import 'package:collection/collection.dart';

import '../../codelessly_sdk.dart';

/// Helpers class that helps parsing raw data into [SceneNode].
class CodelesslyHelper {
  /// Converts map data to [SceneNode].
  @Deprecated('No longer used. Legacy publishing flow.')
  static FetchWebsiteData convertToNode(
    Map<String, dynamic>? event, {
    bool fromHttpFirestore = false,
  }) {
    // Convert to readable values.
    final Map<String, dynamic> parsedData = fromHttpFirestore
        ? _firestoreParser(event!['document'])
        : event!['document'];

    // Convert the previous map into an array of values.
    final List<dynamic> listedData =
        parsedData.entries.map((entry) => entry.value).toList();

    // Reuse the instance.
    final NodeJsonConverter nodeJsonConverter = NodeJsonConverter();

    // Convert to Nodes.
    final List<SceneNode> nodes = listedData
        .map((d) => nodeJsonConverter.fromJson(d))
        .whereType<SceneNode>()
        .toList();

    final List<Breakpoint> breakpoints = [];

    if (event['breakpoints'] != null) {
      final dynamic parsedData = (fromHttpFirestore
          ? _firestoreParser(event['breakpoints'])
          : event['breakpoints']);

      final List<dynamic> listedData =
          parsedData.entries.map((entry) => entry.value).toList();

      breakpoints.addAll(listedData.map((e) => Breakpoint.fromJson(e)));
    }

    final Map<String, SceneNode> map = {for (var e in nodes) e.id: e};
    return FetchWebsiteData(
      nodes: map,
      entryPoint: (event['entryPoint'] != null)
          ? (fromHttpFirestore
              ? _firestoreParser(event['entryPoint'])
              : event['entryPoint'])
          : null,
      breakpoints: breakpoints,
    );
  }

  static String? _getFireStoreProp(Map<String, dynamic> value) {
    final props = <String, int>{
      'nullValue': 1,
      'arrayValue': 1,
      'bytesValue': 1,
      'booleanValue': 1,
      'doubleValue': 1,
      'geoPointValue': 1,
      'integerValue': 1,
      'mapValue': 1,
      'referenceValue': 1,
      'stringValue': 1,
      'timestampValue': 1
    };

    return value.keys.firstWhereOrNull(
      (element) => props[element] == 1,
    );
  }

  // https://stackoverflow.com/a/59003292/4418073
  static dynamic _firestoreParser(dynamic jsonMap) {
    final String? prop = _getFireStoreProp(jsonMap);
    dynamic value = jsonMap;

    if (prop == 'doubleValue' || prop == 'integerValue') {
      value = num.parse(jsonMap[prop].toString());
    } else if (prop == 'arrayValue') {
      // Check if array exists and has 'values' property.
      if (jsonMap[prop] != null &&
          (jsonMap[prop] as Map?)?.containsKey('values') == true) {
        final List<dynamic> array = [];
        (jsonMap[prop]['values'] as List<dynamic>).forEach((d) {
          array.add(_firestoreParser(d));
        });
        value = array;
      } else {
        value = [];
      }
    } else if (prop == 'mapValue') {
      // Check if map exists and has 'fields' property.
      if (jsonMap[prop] != null && jsonMap[prop]['fields'] != null) {
        value = Map<String, dynamic>.from(
            _firestoreParser(jsonMap[prop]['fields']));
      } else {
        value = <String, dynamic>{};
      }
    } else if (prop == 'stringValue' || prop == 'booleanValue') {
      value = jsonMap[prop];
    } else if (prop == 'nullValue') {
      value = null;
    } else if (prop == null) {
      value = <String, dynamic>{};
      jsonMap.keys.forEach((element) {
        value[element] = _firestoreParser(jsonMap[element]);
      });
    }

    return value;
  }
}
