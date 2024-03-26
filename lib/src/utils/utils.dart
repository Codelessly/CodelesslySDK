import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';
import 'constants.dart';

const Set<String> predefinedVariableNames = {
  'data',
  'index',
  'value',
  'item',
  'storage',
  'route',
};

const Set<String> predefinedListenableVariableNames = {'storage'};

final Set<PredefinedVariableData> predefinedVariables = {
  PredefinedVariableData(name: 'data', type: VariableType.map),
  PredefinedVariableData(name: 'index', type: VariableType.integer),
  PredefinedVariableData(name: 'item'),
  PredefinedVariableData(name: 'value'),
  PredefinedVariableData(name: 'storage', type: VariableType.map),
  PredefinedVariableData(name: 'route', type: VariableType.map),
};

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

  bool get hasOnlyAccessor => hasAccessor && !hasPath;

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

/// Returns the most common value in a list.
/// Returns null for ties.
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
BaseNode? getWidestNode(Iterable<BaseNode> siblings) {
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
BaseNode? getTallestNode(Iterable<BaseNode> siblings) {
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

/// If the [parent] is wrapping on an axis, one of its [siblings] is going to be
/// laid out without Positioned or Align, marking the child as the best
/// candidate for the [Stack] to figure out its own size.
///
/// To do this, we need to find the largest child on the axis that the parent
/// is wrapping on. If the parent is wrapping on both axes, we need to find the
/// largest child by multiplying its width and height as a sort of best
/// approximation.
BaseNode? getLargestNodeForWrappingStack(
    BaseNode parent, List<BaseNode> sibling) {
  if (sibling.isEmpty) return null;

  // Only horizontal wrap.
  if (parent.isHorizontalWrap && !parent.isVerticalWrap) {
    return sibling.reduce(
        (a, b) => a.basicBoxLocal.width > b.basicBoxLocal.width ? a : b);
  }

  // Only vertical wrap, compare heights.
  if (parent.isVerticalWrap && !parent.isHorizontalWrap) {
    return sibling.reduce(
        (a, b) => a.basicBoxLocal.height > b.basicBoxLocal.height ? a : b);
  }

  // Both wrap.
  return sibling.reduce((a, b) =>
      a.basicBoxLocal.height * a.basicBoxLocal.width >
              b.basicBoxLocal.height * b.basicBoxLocal.width
          ? a
          : b);
}

AlignmentModel retrieveCommonStackAlignment(
  BaseNode parent,
  List<BaseNode> nodes,
) {
  final List<AlignmentModel> alignments = [];

  if (nodes.length == 1 &&
      nodes.single is ScrollableMixin &&
      (nodes.single as ScrollableMixin).isScrollable) {
    return AlignmentModel.none;
  }

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

  AlignmentModel? bestAlignment = mostCommonAlignment;

  // mostCommonAlignment will be null if a tie exists. In such cases, we
  // completely disregard common alignment and use an Align widget on each child
  // as it is higher quality, more readable code. While that works most of the
  // time, if the stack is wrapping in any axis, all [Align]ed children will be
  // converted into [Positioned] widgets to prevent the Stack from expanding
  // instead of wrapping.
  //
  // With that in mind, if all of the children are Positioned in a wrapping
  // Stack, the Stack will implode on itself as it has no concrete,
  // non-Positioned children and to figure out its first-pass size. The
  // Positioned children end up in a zero-size Stack as a result.
  //
  // To fix this specific situation, we arbitrarily return one of the tied
  // alignments. The stack will use this alignment for its `stackAlignment`
  // property, which does not expand the stack, rather aligns children
  // correctly instead. Once we pass this stack alignment, the singular child
  // that this alignment matches is not going to wrap itself with an Align
  // widget because its alignment matches the stack alignment. This means that
  // the stack will have a concrete child to figure out its size and will not
  // implode. The rest of the children will be wrapped with Positioned widgets
  // in a Stack that has a concrete size.
  if (bestAlignment == null &&
      parent.isOneOrBothWrap &&
      alignments.isNotEmpty) {
    bestAlignment = getLargestNodeForWrappingStack(parent, nodes)?.alignment;
  }

  return bestAlignment ?? AlignmentModel.none;
}

String apiNameToVariableName(String name) {
  if (name.startsWith(RegExp(r'\d+'))) {
    name = name.replaceFirst(RegExp(r'\d+'), '').trim();
  }
  name =
      name.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'\W'), '').trim();
  final tokens = name.split(RegExp(r'_+'));
  final sanitizedName = [
    SDKConstants.apiVariablePrefix,
    ...tokens.map((e) => e.capitalized)
  ].join('');
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

  static Map idle(String url) => {
        'url': url,
        'isIdle': true,
        'isLoading': false,
        'isError': false,
        'isSuccess': false,
        'status': 'idle',
      };

  static Map loading(String url, {Object? data}) => {
        'url': url,
        'isIdle': false,
        'isLoading': true,
        'isError': false,
        'isSuccess': false,
        'status': 'loading',
        'data': data,
        'hasData': data != null,
      };

  static Map error(
    String url,
    Object? error, {
    Object? data,
    Map<String, String>? headers,
  }) =>
      {
        'url': url,
        'isIdle': false,
        'isLoading': false,
        'isError': true,
        'isSuccess': false,
        'error': error is Map || error is List ? error : error.toString(),
        'status': 'error',
        'headers': headers,
        'hasData': data != null,
        'data': data is Map || data is List ? data : data.toString(),
      };

  static Map success(
    String url,
    Object? data, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) =>
      {
        'url': url,
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
      'url': response.request!.url.toString(),
      'isIdle': false,
      'isLoading': false,
      'isError': !isSuccess,
      'isSuccess': isSuccess,
      'data': isSuccess ? body : existingData,
      'error': isSuccess ? null : body,
      // This is handy but can have a lot worse performance if the body is large.
      // 'body': body,
      'status': isSuccess ? 'success' : 'error',
      // This is nice but it doesn't seem to be useful at the moment. We can
      // always add it back later. It's also a bit expensive for large bodies.
      // 'bodyBytes': response.bodyBytes,
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

/// Helper utility class to easily update different statuses for cloud storage variable
class CloudDatabaseVariableUtils {
  CloudDatabaseVariableUtils._();

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
  }) =>
      {
        'isIdle': false,
        'isLoading': false,
        'isError': true,
        'isSuccess': false,
        'error': error is Map || error is List ? error : error.toString(),
        'status': 'error',
        'hasData': data != null,
        'data': data is Map || data is List ? data : data.toString(),
      };

  static Map success(
    Object? data, {
    String? docId,
  }) =>
      {
        'id': docId,
        'isIdle': false,
        'isLoading': false,
        'isError': false,
        'isSuccess': true,
        'data': data,
        'status': 'error',
        'hasData': data != null,
      };
}

/// Constructs a [Query] on top of given [Query] reference using given [whereFilters]
/// and [orderByOperations].
Query<Map<String, dynamic>> constructQueryFromRef(
  Query<Map<String, dynamic>> ref, {
  required List<WhereQueryFilter> whereFilters,
  required List<OrderByQueryFilter> orderByOperations,
  int? limit,
  required ScopedValues scopedValues,
  required NullSubstitutionMode nullSubstitutionMode,
}) {
  Query<Map<String, dynamic>> query = ref;

  if (limit != null) query.limit(limit);

  if (whereFilters.isEmpty && orderByOperations.isEmpty) return query;

  for (final whereFilter in whereFilters) {
    Object? field;
    final matches = VariableMatch.parseAll(whereFilter.field);
    if (matches.length == 1) {
      final match = matches.first;
      if (match.hasRawValue && match.name == 'documentId') {
        field = FieldPath.documentId;
      }
    }
    field ??= PropertyValueDelegate.substituteVariables(
      whereFilter.field,
      scopedValues: scopedValues,
      nullSubstitutionMode: nullSubstitutionMode,
    );
    final Object value = PropertyValueDelegate.substituteVariables(
          whereFilter.value,
          scopedValues: scopedValues,
          nullSubstitutionMode: nullSubstitutionMode,
        ).parsedValue() ??
        '';

    query = switch (whereFilter.operator) {
      WhereQueryOperator.equal => query.where(
          field,
          isEqualTo: value,
        ),
      WhereQueryOperator.notEqual => query.where(
          field,
          isNotEqualTo: value,
        ),
      WhereQueryOperator.arrayContains => query.where(
          field,
          arrayContains: value,
        ),
      WhereQueryOperator.greaterThan => query.where(
          field,
          isGreaterThan: value,
        ),
      WhereQueryOperator.greaterThanOrEqual => query.where(
          field,
          isGreaterThanOrEqualTo: value,
        ),
      WhereQueryOperator.lessThan => query.where(
          field,
          isLessThan: value,
        ),
      WhereQueryOperator.lessThanOrEqual => query.where(
          field,
          isLessThanOrEqualTo: value,
        ),
      WhereQueryOperator.arrayContainsAny => query.where(
          field,
          arrayContainsAny: value.typedValue<List>(),
        ),
      WhereQueryOperator.inArray => query.where(
          field,
          whereIn: value.typedValue<List>(),
        ),
      WhereQueryOperator.notInArray => query.where(
          field,
          whereNotIn: value.typedValue<List>(),
        ),
    };
  }

  for (final orderByFilter in orderByOperations) {
    Object? field;
    final matches = VariableMatch.parseAll(orderByFilter.field);
    if (matches.length == 1) {
      final match = matches.first;
      if (match.hasRawValue && match.name == 'documentId') {
        field = FieldPath.documentId;
      }
    }

    field ??= PropertyValueDelegate.substituteVariables(
      orderByFilter.field,
      scopedValues: scopedValues,
      nullSubstitutionMode: nullSubstitutionMode,
    );

    query = query.orderBy(
      field,
      descending: orderByFilter.sortOrder == OrderByQuerySortOrder.descending,
    );
  }

  return query;
}
