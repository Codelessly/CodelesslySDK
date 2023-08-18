import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';

import '../../codelessly_sdk.dart';

// const String jsonPathPattern = r'\${([a-zA-Z.\[\]]+[a-zA-Z0-9_.\[\]]*)}';
// final RegExp jsonPathRegex = RegExp(jsonPathPattern);

// const String dataJsonPathPattern =
//     r'\${data\.([a-zA-Z.\[\]]+[a-zA-Z0-9_.\[\]]*)}';
// final RegExp dataJsonPathRegex = RegExp(dataJsonPathPattern);

const Set<String> predefinedVariableNames = {'data', 'index', 'item'};

final Set<PredefinedVariableData> predefinedVariables = {
  PredefinedVariableData(name: 'data', type: VariableType.map),
  PredefinedVariableData(name: 'index', type: VariableType.integer),
  PredefinedVariableData(name: 'item'),
};

/// Substitutes json paths found in [text] with values from [data].
/// supported text format:
///   - ${data.name}: will be replaced with data['name'].
///   - data.name: will be replaced with data['name'].
///
Object? substituteJsonPath(String text, Map<String, dynamic> data) {
  // If the text represents a JSON path, get the relevant value from [data] map.
  if (data.isEmpty) return null;

  if (!variableSyntaxIdentifierRegex.hasMatch(text)) {
    // text is not wrapped with ${}. Wrap it since a validation is done later.
    text = '\${$text}';
  }

  if (!text.isValidVariablePath) return null;

  // Remove $-sign and curly brackets.
  String path = variableSyntaxIdentifierRegex.hasMatch(text)
      ? text.substring(2, text.length - 1)
      : text;
  // Add $-sign and dot so that the expression matches JSON path standards.
  path = '\$.$path';
  // [text] represent a JSON path here. Decode it.
  final JsonPath jsonPath = JsonPath(path);
  // Retrieve values from JSON that match the path.
  final values = jsonPath.readValues(data);
  if (values.isEmpty) return null;
  // Return the first value.
  return values.first;
}

List<InlineSpan> transformTextSpans(List<InlineSpan> spans,
    List<VariableData> variables, BuildContext context) {
  return spans.map((span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: PropertyValueDelegate.substituteVariables(context, span.text!),
      style: span.style,
      children: transformTextSpans(span.children ?? [], variables, context),
      locale: span.locale,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
      spellOut: span.spellOut,
    );
  }).toList();
}

/// Returns the greatest common divisor (gcd) of two integers using Euclid's
/// algorithm.
int greatestCommonDivisor(int a, int b) => a.gcd(b);

/// Returns the greatest common divisor (gcd) of the input integers using
/// Euclid's algorithm.
int greatestCommonDivisorOfMany(List<int> integers) {
  if (integers.isEmpty) {
    return 0;
  }

  int gcd = integers[0].abs();

  for (int i = 1; (i < integers.length) && (gcd > 1); i++) {
    gcd = greatestCommonDivisor(gcd, integers[i]);
  }

  return gcd;
}

/// Returns the least common multiple (lcm) of two integers using Euclid's
/// algorithm.
int leastCommonMultiple(int a, int b) {
  if ((a == 0) || (b == 0)) {
    return 0;
  }

  return ((a ~/ greatestCommonDivisor(a, b)) * b).abs();
}

/// Returns the least common multiple (lcm) of many [BigInt] using Euclid's
/// algorithm.
int leastCommonMultipleOfMany(List<int> integers) {
  if (integers.isEmpty) {
    return 1;
  }

  var lcm = integers[0].abs();

  for (var i = 1; i < integers.length; i++) {
    lcm = leastCommonMultiple(lcm, integers[i]);
  }

  return lcm;
}

/// Enum representation of alignment.
enum AlignmentEnum {
  none,
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  custom,
}

/// Parsed data from a variable path using [variablePathRegex].
class VariableMatch with EquatableMixin {
  final String text;
  final String name;
  final String? path;
  final String? accessor;
  final String fullPath;
  final RegExpMatch? match;

  VariableMatch({
    required this.text,
    required this.name,
    required this.path,
    required this.accessor,
    required this.fullPath,
    required this.match,
  });

  /// Returns a parsed [VariableMatch] from [text] if it matches the
  /// [variablePathRegex] pattern. Otherwise, returns null.
  static VariableMatch? parse(String text) {
    final match = variablePathRegex.firstMatch(text);
    if (match == null) return null;
    return fromMatch(match);
  }

  static VariableMatch fromMatch(RegExpMatch match) {
    final name = match.namedGroup('name')!;
    final path = match.namedGroup('path');
    final accessor = match.namedGroup('accessor');
    final fullPath = match.namedGroup('value')!;

    return VariableMatch(
      text: match[0]!,
      name: name,
      path: path,
      accessor: accessor,
      fullPath: fullPath,
      match: match,
    );
  }

  bool get isPredefinedVariable => predefinedVariableNames.contains(name);

  bool get hasPath => path != null && path!.isNotEmpty;

  bool get hasAccessor => accessor != null && accessor!.isNotEmpty;

  bool get hasRawValue => !hasPath && !hasAccessor;

  bool get hasPathOrAccessor => hasPath || hasAccessor;

  static List<VariableMatch> parseAll(String text) =>
      variablePathRegex.allMatches(text).map(VariableMatch.fromMatch).toList();

  @override
  List<Object?> get props => [text, name, path, accessor, fullPath, match];
}

/// Supported image file types that can be dropped on the canvas.
final RegExp supportedAssetTypesRegex =
    RegExp('jpg|jpeg|png|webp|gif|svg', caseSensitive: false);

final RegExp staticImageTypesRegex =
    RegExp('jpg|jpeg|png|webp', caseSensitive: false);
