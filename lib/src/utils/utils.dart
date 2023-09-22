import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';

const Set<String> predefinedVariableNames = {'data', 'index', 'item'};

final Set<PredefinedVariableData> predefinedVariables = {
  PredefinedVariableData(name: 'data', type: VariableType.map),
  PredefinedVariableData(name: 'index', type: VariableType.integer),
  PredefinedVariableData(name: 'item'),
};

List<InlineSpan> transformTextSpans(
  List<InlineSpan> spans,
  List<VariableData> variables,
  BuildContext context,
  WidgetBuildSettings settings,
) {
  return spans.map((span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: PropertyValueDelegate.substituteVariables(
        context,
        span.text!,
        nullSubstitutionMode: settings.nullSubstitutionMode,
      ),
      style: span.style,
      children: transformTextSpans(
        span.children ?? [],
        variables,
        context,
        settings,
      ),
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

/// Queries available scrollable axes determined by children expanding behavior.
///
/// Specifically, this method checks whether any child of a given node is
/// expanding horizontally or vertically. It then returns a record with two bool
/// values: [horizontal] and [vertical].
///
/// If a child node is found to be expanding in a particular direction, the
/// corresponding value in the returned record becomes false.
///
/// Scrollable containers produce unbounded space inside of their bodies,
/// therefore, children of scrollable containers cannot expand to fill that
/// unbounded space.
///
/// [returns] A record with two bool values:
/// - [horizontal] is true if no child is expanding horizontally,
/// - [vertical] is true if no child is expanding vertically.
({bool horizontal, bool vertical}) checkChildrenForLegalScrollableAxes({
  required BaseNode node,
  required GetNode getNode,
  required ScaleMode scaleMode,
}) {
  // Auto scale canvas nodes always force fixed-size children, even if they are
  // set to expanded.
  if (node is CanvasNode && scaleMode == ScaleMode.autoScale) {
    return (
      horizontal: true,
      vertical: true,
    );
  }

  bool isAnyExpandingHorizontally = false;
  bool isAnyExpandingVertically = false;

  final BaseNode delegatedNode;
  if (node is! CanvasNode) {
    delegatedNode = node;
  } else {
    delegatedNode = getNode(node.properties.bodyId);
  }

  final bool hasChildren = delegatedNode.childrenOrEmpty.isNotEmpty;

  if (!hasChildren) {
    return (
      horizontal: false,
      vertical: false,
    );
  }

  for (final id in delegatedNode.childrenOrEmpty) {
    final child = getNode(id);
    isAnyExpandingHorizontally =
        isAnyExpandingHorizontally || child.horizontalFit.isFlex;
    isAnyExpandingVertically =
        isAnyExpandingVertically || child.verticalFit.isFlex;
  }

  return (
    horizontal: !isAnyExpandingHorizontally,
    vertical: !isAnyExpandingVertically,
  );
}

({bool horizontal, bool vertical}) checkSelfForLegalScrollableAxes(
    {required BaseNode node}) {
  if (node is CanvasNode) {
    return (
      horizontal: true,
      vertical: true,
    );
  }

  return (
    horizontal: node.isHorizontalWrap,
    vertical: node.isVerticalWrap,
  );
}

({bool horizontal, bool vertical}) checkParentForLegalScrollableAxes({
  required BaseNode node,
  required GetNode getNode,
}) {
  BaseNode parent = getNode(node.parentID);

  if (parent is PlaceholderMixin) {
    final canvas = getNode(parent.parentID);
    if (canvas is CanvasNode && canvas.properties.bodyId == parent.id) {
      // Autoscale is an exception.
      if (canvas.scaleMode == ScaleMode.autoScale) {
        return (
          horizontal: true,
          vertical: true,
        );
      }

      parent = canvas;
    }
  }

  bool isParentScrollingHorizontally = false;
  bool isParentScrollingVertically = false;
  if (parent is ScrollableMixin && parent.isScrollable) {
    switch (parent.scrollDirection) {
      case AxisC.horizontal:
        isParentScrollingHorizontally = true;
        break;
      case AxisC.vertical:
        isParentScrollingVertically = true;
        break;
    }
  }

  return (
    horizontal: !isParentScrollingHorizontally,
    vertical: !isParentScrollingVertically,
  );
}

AxisC? getBestAxisForScrolling({
  required BaseNode node,
  required GetNode getNode,
  required ScaleMode scaleMode,
}) {
  final availableAxes = checkChildrenForLegalScrollableAxes(
    node: node,
    getNode: getNode,
    scaleMode: scaleMode,
  );

  if (!availableAxes.horizontal && !availableAxes.vertical) {
    return null;
  } else if (availableAxes.horizontal && availableAxes.vertical) {
    return node is ScrollableMixin ? node.scrollDirection : null;
  } else if (availableAxes.horizontal) {
    return AxisC.horizontal;
  } else {
    return AxisC.vertical;
  }
}

bool canScrollOnAxis({
  required BaseNode node,
  required GetNode getNode,
  required AxisC axis,
  required ScaleMode scaleMode,
}) {
  final availableAxes = checkChildrenForLegalScrollableAxes(
    node: node,
    getNode: getNode,
    scaleMode: scaleMode,
  );

  return switch (axis) {
    AxisC.horizontal => availableAxes.horizontal,
    AxisC.vertical => availableAxes.vertical
  };
}

/// Returns the most common value in a list. Returns null for ties.
T? mostCommon<T>(List<T> list) {
  final Map<T, int> counts = {};
  for (final T element in list) {
    counts[element] = (counts[element] ?? 0) + 1;
  }

  final sortedEntries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  if (sortedEntries.length > 1 &&
      sortedEntries[0].value == sortedEntries[1].value) {
    return null;
  }

  return sortedEntries.first.key;
}

/// Retrieves the widest child from given [siblings].
BaseNode? getWidestNode(List<BaseNode> siblings) {
  if (siblings.isEmpty) return null;

  return siblings.reduce((a, b) {
    // If one of the siblings has alignment, while the other does not,
    // return the one with alignment.
    if (a.alignment != AlignmentModel.none &&
        b.alignment == AlignmentModel.none) {
      return a;
    }
    if (b.alignment != AlignmentModel.none &&
        a.alignment == AlignmentModel.none) {
      return b;
    }

    // If both siblings have alignment or both do not have alignment, compare
    // their widths.
    return a.basicBoxLocal.width > b.basicBoxLocal.width ? a : b;
  });
}

/// Retrieves the tallest child from given [siblings].
BaseNode? getTallestNode(List<BaseNode> siblings) {
  if (siblings.isEmpty) return null;

  return siblings.reduce((a, b) {
    // If one of the siblings has alignment, while the other does not,
    // return the one with alignment.
    if (a.alignment != AlignmentModel.none &&
        b.alignment == AlignmentModel.none) {
      return a;
    }
    if (b.alignment != AlignmentModel.none &&
        a.alignment == AlignmentModel.none) {
      return b;
    }

    // If both siblings have alignment or both do not have alignment, compare
    // their heights.
    return a.basicBoxLocal.height > b.basicBoxLocal.height ? a : b;
  });
}

AlignmentModel retrieveCommonStackAlignment(
  BaseNode parent,
  List<BaseNode> nodes,
) {
  final List<AlignmentModel> alignments = [];

  for (final BaseNode node in nodes) {
    final AlignmentModel alignment = node.alignment;
    if (alignment.data == null) continue;
    alignments.add(alignment);
  }

  final AlignmentModel? mostCommonAlignment;

  if (alignments.isEmpty) {
    mostCommonAlignment = null;
  } else {
    mostCommonAlignment = mostCommon<AlignmentModel>(alignments);
  }

  return mostCommonAlignment ??
      (parent.isOneOrBothWrap && alignments.isNotEmpty
          ? AlignmentModel.center
          : AlignmentModel.none);
}

String apiNameToVariableName(String name) {
  if (name.startsWith(RegExp(r'\d+'))) {
    name = name.replaceFirst(RegExp(r'\d+'), '').trim();
  }
  name =
      name.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'\W'), '').trim();
  final tokens = name.split(RegExp(r'_+'));
  final sanitizedName = ['api', ...tokens.map((e) => e.capitalized)].join('');
  return sanitizedName;
}

/// Returns a list of api ids that should be loaded for a given [canvasNode].
Set<String> getApisToLoadForCanvas(CanvasNode canvasNode) {
  return canvasNode.reactions
      .whereTriggerType(TriggerType.load)
      .map((e) => e.action)
      .whereType<ApiCallAction>()
      .map((e) => e.apiId)
      .whereNotNull()
      .toSet();
}

/// Helper utility class to easily convert [ApiResponseVariable] to a map and
/// update different statuses.
class ApiResponseVariableUtils {
  ApiResponseVariableUtils._();

  static Map idle() => {
        'isIdle': true,
        'isLoading': false,
        'isError': false,
        'isSuccess': false,
        'status': 'idle',
      };

  static Map loading({Object? data}) => {
        'isIdle': false,
        'isLoading': true,
        'isError': false,
        'isSuccess': false,
        'status': 'loading',
        'data': data,
        'hasData': data != null,
      };

  static Map error(
    Object? error, {
    Object? data,
    Map<String, String>? headers,
  }) =>
      {
        'isIdle': false,
        'isLoading': false,
        'isError': true,
        'isSuccess': false,
        'error': error,
        'status': 'error',
        'headers': headers,
        'hasData': data != null,
        'data': data,
      };

  static Map success(
    Object? data, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) =>
      {
        'isIdle': false,
        'isLoading': false,
        'isError': false,
        'isSuccess': true,
        'data': data,
        'status': 'error',
        'headers': headers,
        'statusCode': statusCode,
        'hasData': data != null,
      };

  static Map fromResponse(http.Response response, {Object? existingData}) {
    final bool isSuccess =
        response.statusCode >= 200 && response.statusCode < 300;
    final Object body = tryJsonDecode(response.body) ?? response.body;
    return {
      'isIdle': false,
      'isLoading': false,
      'isError': !isSuccess,
      'isSuccess': isSuccess,
      'data': isSuccess ? body : existingData,
      'error': isSuccess ? null : body,
      'body': body,
      'status': isSuccess ? 'success' : 'error',
      'bodyBytes': response.bodyBytes,
      'headers': response.headers,
      'statusCode': response.statusCode,
      'hasData': isSuccess || existingData != null,
    };
  }

// static Object? sanitizeValueForJson(Object? value) {
//   return switch (value) {
//     String() || int() || double() || bool() => value,
//     List() => value.map(sanitizeValueForJson).toList(),
//     Map() => value.map((key, value) =>
//         MapEntry(key.toString(), sanitizeValueForJson(value))),
//     _ => value?.toString(),
//   };
// }
}
