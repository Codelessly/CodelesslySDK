import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

/// Writes a cloud list's query status into its [statusVariable] after the
/// frame, so a layout can show its own loading, empty and error states.
void reportQueryStatus(
  BuildContext context,
  VariableData? statusVariable,
  String status,
) {
  if (statusVariable == null) return;
  final CodelesslyContext? codelesslyContext = context
      .read<CodelesslyContext?>();
  if (codelesslyContext == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final Observable<VariableData>? notifier = codelesslyContext
        .findVariableByName(statusVariable.name);
    if (notifier == null || notifier.value.value == status) return;
    notifier.set(notifier.value.copyWith(value: status));
  });
}

/// The status a query snapshot reports through [reportQueryStatus].
String queryStatusOf({
  required bool isFetching,
  required bool hasError,
  required int count,
}) {
  if (hasError) return kQueryStatusError;
  if (isFetching) return kQueryStatusLoading;
  return count == 0 ? kQueryStatusEmpty : kQueryStatusLoaded;
}
