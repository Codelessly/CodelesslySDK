import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';

import '../../codelessly_sdk.dart';

const String variablePattern = r'\${([a-zA-Z]+[a-zA-Z0-9_]*)}';
final RegExp variableRegex = RegExp(variablePattern);

const String jsonPathPattern = r'\${([a-zA-Z.\[\]]+[a-zA-Z0-9_.\[\]]*)}';
final RegExp jsonPathRegex = RegExp(jsonPathPattern);

String substituteVariables(String characters, List<VariableData> variables) {
  if (variables.isEmpty) return characters;
  return characters.splitMapJoin(
    RegExp(variablePattern),
    onMatch: (match) {
      final String variableName = match.group(1)!;
      return variables.getStringByName(variableName,
          defaultValue: match.group(0)!);
    },
  );
}

String substituteData(String text, Map<String, dynamic> data) {
  // If the text represents a JSON path, get the relevant value from [data] map.
  if (data.isNotEmpty) {
    if (text.isJsonPath) {
      // Remove $-sign and curly brackets.
      String path = text.substring(2, text.length - 1);
      // Add $-sign and dot so that the expression matches JSON path standards.
      path = '\$.$path';
      // [text] represent a JSON path here. Decode it.
      final JsonPath jsonPath = JsonPath(path);
      // Retrieve values from JSON that match the path.
      final values = jsonPath.readValues(data);
      if (values.isNotEmpty) {
        // Only one value should match the path.
        final value = values.first;
        // Type check value and update the text with value.
        if (value is String) text = value;
      }
    }
  }
  return text;
}

String transformText(
    String text, List<VariableData> variables, BuildContext context) {
  text = substituteVariables(text, variables);
  // TODO: Add support for data substitution with JSON path.
  // text = substituteData(text, context);
  return text;
}

List<InlineSpan> transformTextSpans(List<InlineSpan> spans,
    List<VariableData> variables, BuildContext context) {
  return spans.map((span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: transformText(span.text!, variables, context),
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
