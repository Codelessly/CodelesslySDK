import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../codelessly_sdk.dart';

/// Reads a page of a cloud query: [PageRequest.pageSize] documents after the
/// cursor (the last document of the page before), each as its fields with
/// its `id`. The documents the query matches are counted once, for page
/// numbers and "of 312".
///
/// A query Firestore can't run without an index it lacks ([CloudQueryPlan.runsOnClient])
/// is read whole once, finished by the app, and paged from memory.
PageFetcher cloudPageFetcher({
  required Query<Map<String, dynamic>> ref,
  required CloudQuery query,
  Set<String> readyIndexes = const {},
  bool countTotal = true,
}) {
  final CloudQueryPlan plan = query.plan(readyIndexes: readyIndexes);
  Map<String, Object?> dataOf(DocumentSnapshot<Map<String, dynamic>> doc) => {
    'id': doc.id,
    ...?doc.data(),
  };

  if (plan.runsOnClient) {
    List<Object?>? all;
    return (request) async {
      if (all == null) {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await plan
            .applyTo(ref)
            .get();
        all = plan
            .finish(
              snapshot.docs,
              data: (doc) => doc.data(),
              id: (doc) => doc.id,
            )
            .map(dataOf)
            .toList();
      }
      final List<Object?> items = all!;
      final int start = request.offset.clamp(0, items.length);
      final int end = (start + request.pageSize).clamp(0, items.length);
      return PageResult(items.sublist(start, end), totalCount: items.length);
    };
  }

  int? total;
  bool counted = false;
  return (request) async {
    Query<Map<String, dynamic>> page = plan.applyTo(ref);
    final Object? cursor = request.cursor;
    if (cursor is DocumentSnapshot) page = page.startAfterDocument(cursor);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await page
        .limit(request.pageSize)
        .get();
    if (countTotal && !counted) {
      counted = true;
      try {
        total = (await plan.applyTo(ref).count().get()).count;
      } catch (error) {
        DebugLogger.instance.printInfo(
          'Could not count the query: ${describeCloudError(error)}',
          name: 'cloudPageFetcher',
        );
      }
    }
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
        snapshot.docs;
    return PageResult(
      [for (final doc in docs) dataOf(doc)],
      totalCount: total,
      nextCursor: docs.length == request.pageSize && docs.isNotEmpty
          ? docs.last
          : null,
    );
  };
}

/// Matches `${page.page}`, `${page.offset}`, `${page.cursor}`,
/// `${page.pageSize}` and `${page.limit}` in an API's parameters.
final RegExp pageTokenRegex = RegExp(r'\$\{\s*page\.(\w+)\s*\}');

/// Writes the values of [request] into [text] in place of its `${page.*}`
/// tokens. A missing cursor is empty.
String substitutePageTokens(String text, PageRequest request) {
  final Map<String, Object?> values = request.toMap();
  return text.replaceAllMapped(
    pageTokenRegex,
    (match) => '${values[match.group(1)] ?? ''}',
  );
}

/// Reads one value at [path] (dot separated, list indexes allowed) in a
/// decoded JSON [body]; an empty path is the body.
Object? valueAtPath(Object? body, String path) {
  final String trimmed = path.trim();
  if (trimmed.isEmpty) return body;
  return PaginationController.keyOf(body, trimmed);
}

/// Reads a page from the API [model] names: calls it with its parameters,
/// where `${page.*}` reads the page asked for, and reads the page's items,
/// total and next cursor from the response at the model's paths.
///
/// [send] makes the call; it defaults to the app's API call (the API's
/// headers, body and authentication as published).
PageFetcher apiPageFetcher(
  BuildContext context,
  PaginationModel model, {
  Future<http.Response> Function(ApiCallAction action)? send,
}) {
  final Future<http.Response> Function(ApiCallAction action) call =
      send ??
      (action) => FunctionsRepository.makeApiRequestFromAction(
        action,
        context,
        // A throwaway variable: a page doesn't overwrite the API's own.
        Observable<VariableData>(
          RuntimeVariableData(name: '_page', type: VariableType.map),
        ),
      );
  return (request) async {
    final ApiCallAction action = ApiCallAction(
      apiId: model.apiId,
      parameters: {
        for (final MapEntry(:key, :value) in model.parameters.entries)
          key: substitutePageTokens(value, request),
      },
    );
    final http.Response response = await call(action);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'The API answered ${response.statusCode}',
        response.request?.url,
      );
    }
    final Object? body = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    final Object? items = valueAtPath(body, model.itemsPath);
    final Object? total = model.totalPath.isEmpty
        ? null
        : valueAtPath(body, model.totalPath);
    final Object? cursor = model.cursorPath.isEmpty
        ? null
        : valueAtPath(body, model.cursorPath);
    return PageResult(
      items is List ? items : const [],
      totalCount: switch (total) {
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      },
      nextCursor: cursor == '' ? null : cursor,
    );
  };
}
