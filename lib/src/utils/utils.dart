import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../codelessly_sdk.dart';

const Set<String> predefinedVariableNames = {'data', 'index', 'item'};

final Set<PredefinedVariableData> predefinedVariables = {
  PredefinedVariableData(name: 'data', type: VariableType.map),
  PredefinedVariableData(name: 'index', type: VariableType.integer),
  PredefinedVariableData(name: 'item'),
};

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
