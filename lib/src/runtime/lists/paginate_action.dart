// The paginate action: moves the
// pagination controller it names on the action's screen.
import 'package:codelessly_api/codelessly_api.dart' show PaginateAction, PaginateCommand;
import 'package:flutter/foundation.dart';

import '../actions/runner.dart';
import 'pagination.dart';

/// Runs [a]: next, previous, go to a page, first, last, refresh, retry or
/// set the page size of the controller it names. A controller no list on
/// the screen made is skipped.
Future<void> paginateAction(PaginateAction a, ActionRun run) async {
  String resolve(String text) => run.text(text).trim();
  int? number(String text) {
    final value = resolve(text);
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  final name = resolve(a.controller);
  final controller = PaginationRegistry.maybeOf(run.host.tree)?[name];
  if (controller == null) {
    debugPrint('Codelessly: no pagination controller named "$name" is on screen.');
    return;
  }
  switch (a.command) {
    case PaginateCommand.next:
      await controller.next();
    case PaginateCommand.previous:
      await controller.previous();
    case PaginateCommand.goTo:
      final page = number(a.page);
      if (page != null) await controller.goTo(page);
    case PaginateCommand.first:
      await controller.first();
    case PaginateCommand.last:
      await controller.last();
    case PaginateCommand.refresh:
      await controller.refresh();
    case PaginateCommand.retry:
      await controller.retry();
    case PaginateCommand.setPageSize:
      final size = number(a.pageSize);
      if (size != null) await controller.setPageSize(size);
  }
}
