import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rfc_6901/rfc_6901.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../codelessly_sdk.dart';
import '../logging/stat_tracker.dart';
import '../ui/codelessly_dialog_widget.dart';
import '../ui/layout_presentation_route.dart';
import '../ui/codelessly_popover.dart';
import 'action_chain.dart';
import 'app_auth.dart';
import 'cloud_files.dart';

/// Enum representing the types of API requests.
enum ApiRequestType {
  /// Represents a GET request.
  get,

  /// Represents a POST request.
  post,

  /// Represents a PUT request.
  put,

  /// Represents a PATCH request.
  patch,

  /// Represents a DELETE request.
  delete;

  /// Returns a string representation of the API request type.
  String get prettify {
    switch (this) {
      case ApiRequestType.get:
        return 'GET';
      case ApiRequestType.post:
        return 'POST';
      case ApiRequestType.put:
        return 'PUT';
      case ApiRequestType.patch:
        return 'PATCH';
      case ApiRequestType.delete:
        return 'DELETE';
    }
  }
}

class FunctionsRepository {
  static const String name = 'FunctionsRepository';

  static FutureOr performAction(
    BuildContext context,
    ActionModel action, {
    dynamic internalValue,
    bool notify = true,
  }) {
    if (!action.enabled) {
      DebugLogger.instance.printInfo(
        'Action ${action.type} is disabled. Skipping...',
        name: name,
      );
      return true;
    }
    DebugLogger.instance.printInfo('Performing action: $action', name: name);

    switch (action.type) {
      case ActionType.loadFromCloudStorage || ActionType.setCloudStorage:
        StatTracker.instance.track(StatType.cloudAction, action.type.name);
      default:
        StatTracker.instance.track(StatType.action, action.type.name);
    }

    switch (action.type) {
      case ActionType.navigation:
        return navigate(context, action as NavigationAction);
      case ActionType.showDialog:
        return showDialogAction(context, action as ShowDialogAction);
      case ActionType.closeModal:
        final route = ModalRoute.of(context);
        if (route is DialogRoute && route.isCurrent) {
          Navigator.of(context).pop();
          return true;
        }
        return false;
      case ActionType.link:
        launchURL(context, (action as LinkAction));
        return true;
      case ActionType.submit:
        return submitToNewsletter(context, action as SubmitAction);
      case ActionType.setValue:
        setValue(
          context,
          action as SetValueAction,
          internalValue: internalValue,
          notify: notify,
        );
        return true;
      case ActionType.setVariant:
        setVariant(context, action as SetVariantAction, notify: notify);
        return true;
      case ActionType.setVariable:
        return setVariableFromAction(
          context,
          action as SetVariableAction,
          notify: notify,
        );
      case ActionType.callFunction:
        final result = callFunction(context, action as CallFunctionAction);
        // Blocking actions wait for the app's function to finish.
        if (result is Future) return result.then((_) => true);
        return true;
      case ActionType.callApi:
        return callApi(context, action as ApiCallAction);
      case ActionType.setStorage:
        return setStorageFromAction(context, action as SetStorageAction);
      case ActionType.setCloudStorage:
        return setCloudDatabaseFromAction(
          context,
          action as SetCloudStorageAction,
        );
      case ActionType.loadFromCloudStorage:
        return loadFromStorageAction(
          context,
          action as LoadFromCloudStorageAction,
        );
      case ActionType.auth:
        return AppAuth.perform(context, action as AuthAction);
      case ActionType.conditional:
        return runConditional(context, action as ConditionalAction);
      case ActionType.forEach:
        return runForEach(context, action as ForEachAction);
      case ActionType.cloudFiles:
        return CloudFiles.perform(
          context,
          action as CloudFilesAction,
          runActions: (actions) => runActions(context, actions),
        );
      case ActionType.showToast:
        return AppToast.show(context, action as ShowToastAction);
      case ActionType.confirm:
        return runConfirm(context, action as ConfirmAction);
      case ActionType.delay:
        return Future<bool>.delayed(
          Duration(
            milliseconds: delayMilliseconds(
              action as DelayAction,
              ActionChain.scopedValuesOf(context),
            ),
          ),
          () => true,
        );
      case ActionType.cloudData:
        return runCloudData(context, action as CloudDataAction);
      case ActionType.cloudBatch:
        return runCloudBatch(context, action as CloudBatchAction);
      case ActionType.copyToClipboard:
        return copyToClipboard(context, action as CopyToClipboardAction);
      case ActionType.paywall:
        return performPaywallAction(context, action as PaywallAction);
    }
  }

  /// Run a native paywall action in the enclosing paywall surface.
  static Future<bool> performPaywallAction(
    BuildContext context,
    PaywallAction action,
  ) async {
    final controller = context.read<PaywallController?>();
    if (controller == null) {
      throw StateError('Paywall action outside a paywall');
    }
    switch (action.operation) {
      case PaywallOperation.purchase:
        await controller.purchase(slot: action.slot);
      case PaywallOperation.restore:
        await controller.restore();
      case PaywallOperation.selectProduct:
        controller.selectProduct(
          action.slot ?? (throw StateError('Missing product slot')),
        );
      case PaywallOperation.closePaywall:
        controller.close();
      case PaywallOperation.openLegalLink:
        final url = Uri.tryParse(action.url ?? '');
        if (url == null || url.scheme != 'https') {
          throw StateError('Invalid paywall legal URL');
        }
        await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return true;
  }

  /// Copies the text of [action], its variables substituted.
  static Future<bool> copyToClipboard(
    BuildContext context,
    CopyToClipboardAction action,
  ) async {
    final String text = PropertyValueDelegate.substituteVariables(
      action.text,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: ActionChain.scopedValuesOf(context),
    );
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  /// How long [action] waits: its [DelayAction.duration] formula when that
  /// gives a number, else its fixed [DelayAction.milliseconds].
  static int delayMilliseconds(DelayAction action, ScopedValues scopedValues) {
    final String? duration = action.duration;
    if (duration == null || duration.trim().isEmpty) {
      return action.milliseconds;
    }
    final num? value = num.tryParse(
      PropertyValueDelegate.substituteVariables(
        duration,
        scopedValues: scopedValues,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ).trim(),
    );
    return value == null || value < 0 ? action.milliseconds : value.round();
  }

  /// Runs a [CloudDataAction] and puts its result in its result variable
  /// and in `${result}` for the next actions. A failure (a required field
  /// left empty, a missing permission, ...) stops the chain.
  static Future<bool> runCloudData(
    BuildContext context,
    CloudDataAction action,
  ) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final CloudDatabase? database = await awaitCloudDatabase(context);
    if (database is! FirestoreCloudDatabase) {
      throw StateError('The cloud database is not available.');
    }
    try {
      final Object? result = await CloudDataRunner(
        database: database,
        scopedValues: scopedValues,
      ).run(action);
      ActionChain.setResult(result);
      if (action.resultVariable case final VariableData variable) {
        final notifier = codelesslyContext.findVariableByName(variable.name);
        notifier?.set(notifier.value.copyWith(value: result));
      }
      return true;
    } catch (error) {
      DebugLogger.instance.printInfo(
        '${action.operation.label} on ${action.collection} failed: '
        '${describeCloudError(error)}',
        name: name,
      );
      rethrow;
    }
  }

  /// Runs the writes of a [CloudBatchAction] together.
  static Future<bool> runCloudBatch(
    BuildContext context,
    CloudBatchAction action,
  ) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final CloudDatabase? database = await awaitCloudDatabase(context);
    if (database is! FirestoreCloudDatabase) {
      throw StateError('The cloud database is not available.');
    }
    await CloudDataRunner(
      database: database,
      scopedValues: scopedValues,
    ).runBatch(action);
    return true;
  }

  /// Runs [actions] in order, like a trigger's reactions: blocking actions
  /// are awaited and a failure stops the rest by throwing.
  ///
  /// The actions keep running when [context] unmounts mid chain; see
  /// [ActionChain.contextFor].
  static Future<void> runActions(
    BuildContext context,
    List<ActionModel> actions,
  ) async {
    for (final ActionModel action in actions) {
      // [context] may have unmounted while the previous action ran; the
      // chain then runs on with another of its contexts.
      // ignore: use_build_context_synchronously
      final BuildContext? actionContext = _chainContext(context, action);
      if (actionContext == null || !actionContext.mounted) return;
      final FutureOr future = performAction(actionContext, action);
      if (action.nonBlocking) {
        if (future is Future) unawaited(future.then<void>((_) {}));
      } else {
        await future;
      }
    }
  }

  /// Runs the branch of [action] its expression picks.
  static Future<bool> runConditional(
    BuildContext context,
    ConditionalAction action,
  ) async {
    final bool matches =
        action.expression.accept<bool>(
          ConditionEvaluator<Object>(
            scopedValues: ActionChain.scopedValuesOf(context),
          ),
        ) ==
        true;
    DebugLogger.instance.printInfo(
      'Conditional action took the ${matches ? 'if' : 'else'} branch.',
      name: name,
    );
    await runActions(context, matches ? action.actions : action.elseActions);
    return true;
  }

  /// Asks the user to confirm [action], then runs its actions or its cancel
  /// actions.
  static Future<bool> runConfirm(
    BuildContext context,
    ConfirmAction action,
  ) async {
    final ConfirmOutcome outcome = await AppConfirmDialog.ask(context, action);
    final bool confirmed = outcome.confirmed;
    // What a canvas dialog passed back, e.g. a reason typed into it, is the
    // `${result}` its confirm actions read.
    if (outcome.values case final Map<String, dynamic> values
        when values.isNotEmpty) {
      ActionChain.setResult(values);
    }
    DebugLogger.instance.printInfo(
      'Confirm dialog was ${confirmed ? 'confirmed' : 'cancelled'}.',
      name: name,
    );
    // The confirmed actions run even when the widget that asked has
    // unmounted meanwhile; see [ActionChain.contextFor].
    await runActions(
      // ignore: use_build_context_synchronously
      context,
      confirmed ? action.actions : action.cancelActions,
    );
    return true;
  }

  /// Runs the nested actions of [action] once per item of its list, with
  /// `${result.item}` and `${result.index}` set.
  static Future<bool> runForEach(
    BuildContext context,
    ForEachAction action,
  ) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final String path = action.items.trim();
    final Object? value = path.isEmpty
        ? null
        : PropertyValueDelegate.getVariableValueFromPath(
            path.wrapWithVariableSyntax(),
            scopedValues: scopedValues,
          );
    // A cloud variable keeps its documents under `data`.
    final Object? items = value is Map && value['data'] is List
        ? value['data']
        : value;
    if (items is! List) {
      DebugLogger.instance.printInfo(
        'For each: [${action.items}] is not a list. Skipping.',
        name: name,
      );
      return true;
    }
    final List snapshot = List.of(items);
    for (int index = 0; index < snapshot.length; index++) {
      await ActionChain.run(
        () => runActions(context, action.actions),
        result: {'item': snapshot[index], 'index': index},
      );
    }
    return true;
  }

  /// Calls [action]'s API, then runs its onSuccess actions after a 2xx
  /// response or its onError actions after any other response or a failed
  /// request. Both read the response as `${result}`. A failed request stops
  /// the chain only when there are no onError actions to handle it.
  static Future<http.Response?> callApi(
    BuildContext context,
    ApiCallAction action, [
    Observable<VariableData>? variable,
  ]) async {
    http.Response? response;
    Object? failure;
    StackTrace? failureStack;
    try {
      response = await makeApiRequestFromAction(action, context, variable);
    } catch (error, stackTrace) {
      failure = error;
      failureStack = stackTrace;
    }
    // The widget that made the call can be gone by now (a dialog closed
    // while it loaded); its handlers then run on the chain's opener.
    // ignore: use_build_context_synchronously
    final BuildContext? outcomeContext = ActionChain.contextFor(context);
    if (outcomeContext == null) return response;
    await handleApiOutcome(
      // ignore: use_build_context_synchronously
      outcomeContext,
      action,
      response: response,
      failure: failure,
      failureStack: failureStack,
    );
    return response;
  }

  /// Runs [action]'s onSuccess actions after a 2xx [response], or its onError
  /// actions otherwise. Rethrows [failure] (a request that didn't complete)
  /// when there are no onError actions, so the chain stops as before.
  static Future<void> handleApiOutcome(
    BuildContext context,
    ApiCallAction action, {
    http.Response? response,
    Object? failure,
    StackTrace? failureStack,
  }) async {
    final bool ok =
        failure == null &&
        response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 300;
    if (ok) {
      if (action.onSuccess.isNotEmpty) {
        await runActions(context, action.onSuccess);
      }
    } else if (action.onError.isNotEmpty) {
      await runActions(context, action.onError);
    } else if (failure != null) {
      Error.throwWithStackTrace(failure, failureStack ?? StackTrace.current);
    }
  }

  static Future<http.Response> makeApiRequestFromAction(
    ApiCallAction action,
    BuildContext context, [
    Observable<VariableData>? variable,
  ]) {
    final Map<String, HttpApiData> apis = context
        .read<Codelessly>()
        .dataManager
        .publishModel!
        .apis;

    final HttpApiData? apiData = apis[action.apiId];

    final Codelessly codelessly = context.read<Codelessly>();

    if (apiData == null) {
      codelessly.errorLogger.captureException(
        'Api not found',
        message: 'Api with id [${action.apiId}] does not exist.',
        type: 'api_not_found',
        layoutID: context.read<CodelesslyWidgetController>().layoutID,
      );
      return Future.error('Api with id [${action.apiId}] does not exist.');
    }

    if (variable == null) {
      // Find a variable for the api and pass it.
      // This makes it so the same variable for the api gets updated. This
      // helps updating UI with new data.
      final codelesslyContext = context.read<CodelesslyContext>();
      final name = apiNameToVariableName(apiData.name);
      variable = codelesslyContext.findVariableByName(name);
    }

    // set default values for action parameters.
    final Map<String, String> params = {};
    for (final MapEntry(key: name, :value) in action.parameters.entries) {
      if (value.isNotEmpty) {
        params[name] = value;
        continue;
      }
      // fetch default value from api data.
      final param = apiData.variables.findByNameOrNull(name);
      final paramValue = param != null && param.value.isNotEmpty
          ? param.value
          : '';
      params[name] = paramValue;
    }

    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);

    return makeApiRequest(
      context: context,
      method: apiData.method,
      url: buildApiUrl(apiData, params, scopedValues),
      headers: _generateMapFromPairs(apiData.headers, params, scopedValues),
      body: apiData.bodyType == RequestBodyType.form
          ? _generateMapFromPairs(apiData.formFields, params, scopedValues)
          : _applyApiInputs(apiData.body ?? '', params, scopedValues),
      variable: variable,
    );
  }

  /// The URL [api] requests with the inputs [params]: its URL with inputs
  /// and variables substituted, plus its query parameters (used, non-empty
  /// keys; same substitution), which win over ones written in the URL.
  static String buildApiUrl(
    HttpApiData api,
    Map<String, String> params,
    ScopedValues scopedValues,
  ) {
    final String url = _applyApiInputs(api.url, params, scopedValues);
    final Map<String, String> query = _generateMapFromPairs(
      api.queryParams,
      params,
      scopedValues,
    );
    if (query.isEmpty) return url;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...query})
        .toString();
  }

  static Map<String, String> _generateMapFromPairs(
    List<HttpKeyValuePair> pairs,
    Map<String, String> parameters,
    ScopedValues scopedValues,
  ) {
    return pairs
        .where((pair) => pair.isUsed && pair.key.isNotEmpty)
        .toList()
        .asMap()
        .map(
          (key, pair) => MapEntry(
            _applyApiInputs(pair.key, parameters, scopedValues),
            _applyApiInputs(pair.value, parameters, scopedValues),
          ),
        );
  }

  static String _applyApiInputs(
    String data,
    Map<String, String> parameters,
    ScopedValues scopedValues,
  ) {
    final updatedData = data.replaceAllMapped(inputRegex, (match) {
      final MapEntry<String, String>? parameter = parameters.entries
          .firstWhereOrNull((entry) => entry.key == match.group(1));
      if (parameter == null) {
        DebugLogger.instance.printInfo(
          'parameter ${match.group(1)} not found',
          name: name,
        );
        return match[0]!;
      }
      // Substitute variables in parameter value.
      return PropertyValueDelegate.substituteVariables(
        parameter.value,
        nullSubstitutionMode: NullSubstitutionMode.nullValue,
        scopedValues: scopedValues,
      );
    });
    return updatedData;
  }

  static Map<String, dynamic> substituteVariablesInMap(
    Map<String, dynamic> data,
    ScopedValues scopedValues,
  ) {
    // Substitute variables in params.
    final Map<String, dynamic> parsedParams = {};

    for (final MapEntry(:key, :value) in data.entries) {
      final parsedKey = PropertyValueDelegate.substituteVariables(
        key,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      final parsedValue = PropertyValueDelegate.substituteVariables(
        value is! String ? jsonEncode(value) : value,
        nullSubstitutionMode: NullSubstitutionMode.nullValue,
        scopedValues: scopedValues,
      ).parsedValue();

      // don't add empty keys to the map.
      if (parsedKey.isNotEmpty) parsedParams[parsedKey] = parsedValue;
    }
    return parsedParams;
  }

  static Future<void> navigate(
    BuildContext context,
    NavigationAction action, {
    Codelessly? codelessly,
    CodelesslyWidgetController? codelesslyController,
    ScopedValues? scopedValues,
  }) async {
    final ScopedValues effectiveScopedValues =
        scopedValues ?? ActionChain.scopedValuesOf(context);
    final parsedParams = substituteVariablesInMap(
      action.params,
      effectiveScopedValues,
    );

    DebugLogger.instance.printInfo(
      'Performing navigation action with params: $parsedParams',
      name: name,
    );

    final Codelessly effectiveCodelessly =
        codelessly ?? context.read<Codelessly>();
    final String? myLayoutId = effectiveCodelessly.currentNavigatedLayoutId;
    final String? myCanvasId = effectiveCodelessly.currentNavigatedCanvasId;

    if (action.navigationType == NavigationType.pop) {
      final bool popped = await Navigator.maybePop(context, parsedParams);
      // Nothing to go back to (the screen was opened directly): a pop with a
      // destination goes there instead.
      if (!popped && action.destinationId.isNotEmpty && context.mounted) {
        return navigate(
          context,
          action.copyWith(navigationType: NavigationType.replace),
          codelessly: codelessly,
          codelesslyController: codelesslyController,
          scopedValues: scopedValues,
        );
      }
    } else {
      // Check if a layout exists for the action's [destinationId].
      final String? layoutId = resolveLayoutIdForCanvas(
        effectiveCodelessly.dataManager.publishModel,
        action.destinationId,
      );

      DebugLogger.instance.printInfo(
        'looking for layout with canvas id: [${action.destinationId}]',
        name: name,
      );
      for (final layout
          in effectiveCodelessly.dataManager.publishModel!.layouts.values) {
        DebugLogger.instance.printInfo(
          'layout [${layout.id}] canvas ids: [${layout.canvasIds.join(', ')}]',
          name: name,
        );
      }

      if (layoutId == null) {
        effectiveCodelessly.errorLogger.captureException(
          'Layout not found',
          message:
              'Could not find a layout with a canvas id of [${action.destinationId}]',
          type: 'layout_not_found',
          layoutID: layoutId,
        );
        return;
      }

      final parentController =
          codelesslyController ?? context.read<CodelesslyWidgetController>();
      final effectiveController = parentController.copyWith(
        layoutID: layoutId,
        codelessly: effectiveCodelessly,
      );

      if (action.navigationType == NavigationType.push) {
        // A chain triggered on the page can finish on this layout after
        // the page pops.
        final List<BuildContext> openerHosts = ActionChainOpener.hostsFor(
          context,
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(arguments: parsedParams),
            builder: (context) => ActionChainOpener(
              openerHosts: openerHosts,
              child: CodelesslyWidget(controller: effectiveController),
            ),
          ),
        );
        // Notify navigation listeners that this screen has been navigated back
        // to, because the Navigator.push future has completed and came
        // back to this screen.
        if (context.mounted) {
          effectiveCodelessly.notifyNavigationListeners(
            context,
            layoutId: myLayoutId,
            canvasId: myCanvasId,
          );
        }
      } else if (action.navigationType == NavigationType.replace) {
        // The new screen takes over the chain: the actions after this one
        // (e.g. a toast) run with it once this screen unmounts.
        final ActionChain? chain = ActionChain.current;
        // Don't wait for the route's result: it only comes when the new
        // screen pops, long after this screen is gone, and the rest of the
        // chain would never run.
        unawaited(
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              settings: RouteSettings(arguments: parsedParams),
              builder: (context) {
                final Widget page = CodelesslyWidget(
                  controller: effectiveController,
                );
                if (chain == null) return page;
                return ActionChainAdopter(chain: chain, child: page);
              },
            ),
          ),
        );
      }
    }
  }

  /// Shows [action]'s canvas. What its "Navigate back" passes back, e.g. the
  /// values of a form in a sheet, is the `${result}` of the actions after it.
  static Future<void> showDialogAction(
    BuildContext context,
    ShowDialogAction action,
  ) async {
    final Object? result = await showLayoutDialog(
      context,
      canvasId: action.destinationId,
      params: action.params,
      barrierDismissible: action.barrierDismissible,
      barrierColor: action.barrierColor?.toFlutterColor(),
      showCloseButton: action.showCloseButton,
      presentation: action.presentation,
      alignment: action.alignment.flutterAlignment ?? Alignment.center,
      sheetWidth: action.sheetWidth,
      insets: action.insets.flutterEdgeInsets,
      maxHeightFactor: action.maxHeightFactor,
      showDragHandle: action.showDragHandle,
      placement: action.placement,
      anchorToTrigger: action.anchor == DialogAnchor.trigger,
      anchorGap: action.anchorGap,
      anchorOffset: action.anchorOffset,
      fullHeight: action.fullHeight,
    );
    if (result case final Map values when values.isNotEmpty) {
      ActionChain.setResult(values);
    }
  }

  /// The rect of the node that [context] belongs to, relative to its
  /// navigator overlay. Null when it has no laid-out box.
  static Rect? anchorRectOf(BuildContext context) {
    if (!context.mounted) return null;
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    // In the coordinates of the navigator the popover opens in, which need
    // not start at the screen's corner (a nested navigator under a bar).
    final RenderObject? overlay = Navigator.maybeOf(context)?.overlay?.context
        .findRenderObject();
    return object.localToGlobal(
          Offset.zero,
          ancestor: overlay is RenderBox && overlay.attached ? overlay : null,
        ) &
        object.size;
  }

  /// The size canvas [canvasId] was designed at, if it is published.
  static Size? canvasDesignSize(Codelessly codelessly, String canvasId) {
    final BaseNode? canvas = publishedCanvas(codelessly, canvasId);
    if (canvas == null) return null;
    return Size(canvas.basicBoxLocal.width, canvas.basicBoxLocal.height);
  }

  /// The canvas node [canvasId], if it is published and downloaded.
  static CanvasNode? publishedCanvas(Codelessly codelessly, String canvasId) {
    for (final layout
        in codelessly.dataManager.publishModel?.layouts.values ??
            const <SDKPublishLayout>[]) {
      final BaseNode? canvas = layout.canvases[canvasId]?[canvasId];
      if (canvas is CanvasNode) return canvas;
    }
    return null;
  }

  /// The id of the published layout that holds the canvas [canvasId], if any.
  static String? layoutIdForCanvas(Codelessly codelessly, String canvasId) =>
      resolveLayoutIdForCanvas(codelessly.dataManager.publishModel, canvasId);

  /// The id of the layout of [model] that holds canvas [canvasId], including
  /// layouts indexed but not yet downloaded.
  static String? resolveLayoutIdForCanvas(
    SDKPublishModel? model,
    String canvasId,
  ) {
    if (model == null || canvasId.isEmpty) return null;
    return model.resolveLayoutId(canvasId);
  }

  /// Shows canvas [canvasId] as a dialog, sheet or placed popover and returns
  /// the closing action's params, or null when dismissed.
  static Future<Object?> showLayoutDialog(
    BuildContext context, {
    required String canvasId,
    Map<String, dynamic> params = const {},
    bool barrierDismissible = true,
    Color? barrierColor,
    bool showCloseButton = false,
    DialogPresentation presentation = DialogPresentation.dialog,
    AlignmentGeometry alignment = Alignment.center,
    double? sheetWidth,
    EdgeInsets insets = EdgeInsets.zero,
    double? maxHeightFactor,
    bool showDragHandle = false,
    DialogPlacement placement = DialogPlacement.belowStart,
    bool anchorToTrigger = false,
    double anchorGap = 6,
    double anchorOffset = 0,
    bool fullHeight = false,
  }) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final parsedParams = substituteVariablesInMap(params, scopedValues);

    DebugLogger.instance.printInfo(
      'Performing show dialog action with params: $parsedParams',
      name: name,
    );

    final Codelessly codelessly = context.read<Codelessly>();
    final String? myLayoutId = codelessly.currentNavigatedLayoutId;
    final String? myCanvasId = codelessly.currentNavigatedCanvasId;

    // Check if a layout exists for the action's [destinationId].
    final String? layoutId = layoutIdForCanvas(codelessly, canvasId);

    DebugLogger.instance.printInfo(
      'looking for layout with canvas id: [$canvasId]',
      name: name,
    );
    for (final layout
        in codelessly.dataManager.publishModel?.layouts.values ??
            const <SDKPublishLayout>[]) {
      DebugLogger.instance.printInfo(
        'layout [${layout.id}] canvas ids: [${layout.canvasIds.join(', ')}]',
        name: name,
      );
    }

    if (layoutId == null) {
      codelessly.errorLogger.captureException(
        'Layout not found',
        message: 'Could not find a layout with a canvas id of [$canvasId]',
        type: 'layout_not_found',
        layoutID: layoutId,
      );
      return null;
    }

    // A chain triggered in the dialog can finish on this layout after the
    // dialog closes (e.g. Navigate back, then a toast).
    final List<BuildContext> openerHosts = ActionChainOpener.hostsFor(context);
    final CanvasNode? canvas = publishedCanvas(codelessly, canvasId);
    final DialogPresentation effectivePresentation =
        presentation == DialogPresentation.dialog
        ? switch (placement) {
            DialogPlacement.bottomSheet => DialogPresentation.bottomSheet,
            DialogPlacement.adaptive => DialogPresentation.adaptive,
            _ => presentation,
          }
        : presentation;
    final bool wantsAnchor =
        effectivePresentation == DialogPresentation.dialog &&
        (anchorToTrigger || placement == DialogPlacement.anchored);
    final Rect? anchorRect = wantsAnchor
        ? CodelesslyPopover.anchorRectOf(
            context,
            Navigator.of(context, rootNavigator: false),
          )
        : null;
    if (wantsAnchor && anchorRect == null) {
      DebugLogger.instance.printInfo(
        'The trigger of dialog [$canvasId] has no laid out box; showing '
        'the dialog centered.',
        name: name,
      );
    }
    final RouteSettings routeSettings = RouteSettings(arguments: parsedParams);
    final Object? result = anchorRect == null
        ? await presentCanvas<Object?>(
            context,
            presentation: effectivePresentation,
            alignment: alignment,
            barrierDismissible: barrierDismissible,
            barrierColor: barrierColor,
            showCloseButton: showCloseButton,
            sheetWidth: sheetWidth,
            designSize: canvasDesignSize(codelessly, canvasId),
            hugsContent:
                canvas != null && CanvasViewport.sizesToContent(canvas),
            insets: insets,
            maxHeightFactor: maxHeightFactor,
            showDragHandle: showDragHandle,
            fullHeight: fullHeight,
            anchor: effectivePresentation == DialogPresentation.popover
                ? anchorRectOf(context)
                : null,
            routeSettings: routeSettings,
            builder: (context) => ActionChainOpener(
              openerHosts: openerHosts,
              child: CodelesslyWidget(
                codelessly: codelessly,
                layoutID: layoutId,
              ),
            ),
          )
        : await CodelesslyPopover.show<Object?>(
            context: context,
            anchorRect: anchorRect,
            placement: placement == DialogPlacement.anchored
                ? DialogPlacement.belowStart
                : placement,
            gap: anchorGap,
            offset: anchorOffset,
            barrierDismissible: barrierDismissible,
            barrierColor: barrierColor,
            routeSettings: routeSettings,
            builder: (context) => ActionChainOpener(
              openerHosts: openerHosts,
              child: CodelesslyDialogWidget(
                showCloseButton: showCloseButton,
                anchored: true,
                builder: (context) => CodelesslyWidget(
                  codelessly: codelessly,
                  layoutID: layoutId,
                ),
              ),
            ),
          );
    if (context.mounted) {
      codelessly.notifyNavigationListeners(
        context,
        layoutId: myLayoutId,
        canvasId: myCanvasId,
      );
    }
    return result;
  }

  /// Opens a canvas as a dialog, sheet or anchored popover. The canvas draws
  /// its own surface; sheets may use their design height or hug content.
  static Future<T?> presentCanvas<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    DialogPresentation presentation = DialogPresentation.dialog,
    AlignmentGeometry alignment = Alignment.center,
    EdgeInsets insets = EdgeInsets.zero,
    bool barrierDismissible = true,
    Color? barrierColor,
    bool showCloseButton = false,
    double? maxHeightFactor,
    Size? designSize,
    bool hugsContent = false,
    RouteSettings? routeSettings,
    double? sheetWidth,
    bool showDragHandle = false,
    Rect? anchor,
    bool fullHeight = false,
  }) {
    if (presentation == DialogPresentation.popover) {
      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: barrierDismissible,
        barrierLabel: 'Close',
        barrierColor: barrierColor ?? Colors.transparent,
        transitionDuration: const Duration(milliseconds: 120),
        routeSettings: routeSettings,
        pageBuilder: (context, _, _) => CodelesslyPopoverWidget(
          anchor: anchor,
          builder: builder,
          alignEnd: alignment.resolve(TextDirection.ltr).x > 0,
        ),
        transitionBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );
    }
    if (presentation == DialogPresentation.sideSheet) {
      return Navigator.of(context).push<T>(
        LayoutPresentationRoute<T>(
          context: context,
          presentation: presentation,
          barrierDismissible: barrierDismissible,
          barrierColor:
              barrierColor ??
              Theme.of(context).dialogTheme.barrierColor ??
              Colors.black54,
          showCloseButton: showCloseButton,
          sheetWidth: sheetWidth,
          designWidth: designSize?.width,
          insets: insets,
          hugsContent: hugsContent && insets != EdgeInsets.zero,
          settings: routeSettings,
          builder: builder,
        ),
      );
    }
    final Size? screen = MediaQuery.maybeSizeOf(context);
    final bool asSheet = switch (presentation) {
      DialogPresentation.dialog ||
      DialogPresentation.fullScreen ||
      DialogPresentation.sideSheet ||
      DialogPresentation.popover => false,
      DialogPresentation.bottomSheet => true,
      DialogPresentation.adaptive => (screen?.width ?? 1024) < 600,
    };
    Widget content(BuildContext context, CanvasSizing sizing) =>
        asSheet && fullHeight
        ? CodelesslyBottomSheetWidget(builder: builder)
        : CodelesslyDialogWidget(
            showCloseButton: showCloseButton,
            sizing: sizing,
            alignment: asSheet ? Alignment.bottomCenter : alignment,
            maxHeightFactor: asSheet ? null : maxHeightFactor,
            builder: builder,
          );

    if (asSheet) {
      // As wide as the screen and as tall as its content, up to 90% of the
      // screen; the canvas draws its own background and corners.
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: false,
        isScrollControlled: true,
        isDismissible: barrierDismissible,
        enableDrag: barrierDismissible,
        barrierColor: barrierColor,
        // The canvas draws the sheet: its fill, corners and grab handle.
        backgroundColor: Colors.transparent,
        elevation: 0,
        showDragHandle: showDragHandle,
        constraints: const BoxConstraints(),
        routeSettings: routeSettings,
        builder: (context) {
          final Size screen = MediaQuery.sizeOf(context);
          final double cap =
              CodelesslyDialogWidget.maxHeightFor(
                maxHeightFactor,
                screen.height,
              ) ??
              screen.height * 0.88;
          if (fullHeight) return content(context, CanvasSizing.sheet);
          if (hugsContent) {
            return CanvasSizingScope(
              sizing: CanvasSizing.design,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: screen.width,
                  maxHeight: cap,
                ),
                child: Builder(builder: builder),
              ),
            );
          }
          return CanvasSizingScope(
            sizing: CanvasSizing.fill,
            child: SizedBox(
              height: math.min(designSize?.height ?? double.infinity, cap),
              child: Builder(builder: builder),
            ),
          );
        },
      );
    }
    if (presentation == DialogPresentation.fullScreen) {
      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: barrierDismissible,
        barrierLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
        barrierColor: barrierColor ?? Colors.black,
        routeSettings: routeSettings,
        transitionDuration: const Duration(milliseconds: 200),
        transitionBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (context, _, _) => content(context, CanvasSizing.fill),
      );
    }
    return showDialog<T>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      routeSettings: routeSettings,
      builder: (context) => Padding(
        padding: insets,
        child: maxHeightFactor == null
            ? content(context, CanvasSizing.design)
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.sizeOf(context).height *
                      maxHeightFactor.clamp(0, 1),
                ),
                child: content(context, CanvasSizing.design),
              ),
      ),
    );
  }

  static void launchURL(BuildContext context, LinkAction action) {
    final url = PropertyValueDelegate.substituteVariables(
      action.url,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: ActionChain.scopedValuesOf(context),
    ).trim();
    openLink(url);
  }

  /// Opens [url] with the platform, logging instead of throwing when it is
  /// malformed or cannot be launched.
  static void openLink(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) {
      DebugLogger.instance.printInfo(
        'Invalid URL: $url, Skipping...',
        name: name,
      );
      return;
    }
    DebugLogger.instance.printInfo('Launching URL: $uri', name: name);
    unawaited(
      launchUrl(uri).then<void>(
        (_) {},
        onError: (Object e, StackTrace stackTrace) =>
            ErrorLogger.instance.captureException(
              e,
              message: 'Failed to launch $url',
              type: 'launch_url_failed',
              stackTrace: stackTrace,
            ),
      ),
    );
  }

  static Future<http.Response> makeApiRequest({
    required HttpMethod method,
    required String url,
    required Map<String, String> headers,
    required Object? body,
    required BuildContext context,
    bool useCloudFunctionForWeb = false,
    Observable<VariableData>? variable,
  }) async {
    assert(
      variable == null || variable.value.type.isMap,
      'Provided variable for api call must be of type map. Found ${variable.value.type}',
    );

    printApiDetails(method: method, url: url, headers: headers, body: body);

    // persist previous api call data if there is any. This allows us to
    // show previous data while new data is being fetched.
    final existingData = variable?.value.getValue().typedValue<Map>()?['data'];
    if (variable != null) {
      variable.value = variable.value.copyWith(
        value: ApiResponseVariableUtils.loading(url, data: existingData),
      );
      DebugLogger.instance.printInfo(
        '${variable.value.name} updated with loading state.',
        name: name,
      );
    } else {
      DebugLogger.instance.printInfo(
        'No variable provided for api call.',
        name: name,
      );
    }

    try {
      final http.Response response;
      if (kIsWeb && useCloudFunctionForWeb) {
        final codelessly = context.read<Codelessly>();
        final client = codelessly.client;
        final String cloudFunctionsURL =
            codelessly.config!.firebaseCloudFunctionsBaseURL;
        final receivedResponse = await makeApiRequestWeb(
          method: method,
          url: url,
          headers: headers,
          body: body,
          cloudFunctionsURL: cloudFunctionsURL,
          client: client,
        );

        // cloud function returns actual response in body.
        final actualResponse = json.decode(receivedResponse.body);
        response = http.Response(
          jsonEncode(actualResponse['body'] ?? ''),
          int.parse(actualResponse['statusCode'].toString()),
          headers: Map<String, String>.from(actualResponse['headers'] ?? {}),
          reasonPhrase: actualResponse['reasonPhrase']?.toString(),
        );
      } else {
        final codelessly = context.read<Codelessly>();
        final client = codelessly.client;
        final Uri uri = Uri.parse(url);
        response = switch (method) {
          HttpMethod.get => await client.get(uri, headers: headers),
          HttpMethod.post => await client.post(
            uri,
            headers: headers,
            body: body,
          ),
          HttpMethod.delete => await client.delete(
            uri,
            headers: headers,
            body: body,
          ),
          HttpMethod.put => await client.put(uri, headers: headers, body: body),
        };
      }

      printResponse(response);

      final Map responseValue = ApiResponseVariableUtils.fromResponse(response);
      // The next actions of the chain read the response as `${result}`, e.g.
      // `${result.data}` or `${result.isError}`, even when the API has no
      // variable or another call overwrites it, as in a forEach.
      ActionChain.setResult(responseValue);
      if (variable != null) {
        variable.value = variable.value.copyWith(value: responseValue);
        DebugLogger.instance.printInfo(
          '${variable.value.name} updated with success state.',
          name: name,
        );
      } else {
        DebugLogger.instance.printInfo(
          'No variable provided for api call.',
          name: name,
        );
      }

      return response;
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      final Map errorValue = ApiResponseVariableUtils.error(
        url,
        error,
        data: existingData,
      );
      ActionChain.setResult(errorValue);
      if (variable != null) {
        variable.value = variable.value.copyWith(value: errorValue);
        DebugLogger.instance.printInfo(
          '${variable.value.name} updated with error state.',
          name: name,
        );
      } else {
        DebugLogger.instance.printInfo(
          'No variable provided for api call.',
          name: name,
        );
      }
      return Future.error(error);
    }
  }

  static void printApiDetails({
    required HttpMethod method,
    required String url,
    required Map<String, String> headers,
    required Object? body,
  }) {
    if (kReleaseMode) return;
    DebugLogger.instance.printInfo(
      '--------------------------------------------------------------------',
      name: name,
    );
    DebugLogger.instance.printInfo('API Request:', name: name);
    DebugLogger.instance.printInfo(
      '--------------------------------------------------------------------',
      name: name,
    );
    DebugLogger.instance.printInfo('${method.shortName} $url', name: name);
    DebugLogger.instance.printInfo(
      'Headers: ${headers.isEmpty ? 'None' : ''}',
      name: name,
    );
    if (headers.isNotEmpty) {
      DebugLogger.instance.printInfo(
        const JsonEncoder.withIndent('  ').convert(headers),
        name: name,
      );
      DebugLogger.instance.printInfo('', name: name);
    }
    DebugLogger.instance.printInfo(
      'Body: ${body == null || body.toString().trim().isEmpty ? 'None' : ''}',
      name: name,
    );
    if (body != null && body.toString().trim().isNotEmpty) {
      try {
        final parsed = json.decode(body.toString());
        DebugLogger.instance.printInfo(
          const JsonEncoder.withIndent('  ').convert(parsed),
          name: name,
        );
      } catch (e) {
        DebugLogger.instance.printInfo(body.toString(), name: name);
      }
    }
    DebugLogger.instance.printInfo(
      '--------------------------------------------------------------------',
      name: name,
    );
  }

  static void printResponse(http.Response response) {
    if (kReleaseMode) return;
    DebugLogger.instance.printInfo('''
--------------------------------------------------------------------
Response:
--------------------------------------------------------------------
Status Code: ${response.statusCode}
Headers:
${const JsonEncoder.withIndent('  ').convert(response.headers)}

Body:
${response.body.contains('{') ? const JsonEncoder.withIndent('  ').convert(json.decode(response.body)) : response.body}
--------------------------------------------------------------------
''', name: name);
  }

  /// Makes API request using cloud function to prevent any CORS issues.
  static Future<http.Response> makeApiRequestWeb({
    required HttpMethod method,
    required String url,
    required Map<String, dynamic> headers,
    required Object? body,
    required String cloudFunctionsURL,
    required http.Client client,
  }) async {
    return client.post(
      Uri.parse('$cloudFunctionsURL/makeApiRequest'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'url': url,
        'method': method.shortName,
        'headers': headers,
        'body': body,
      }),
    );
  }

  static Future<void> submitToNewsletter(
    BuildContext context,
    SubmitAction action,
  ) async {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get primary linked text field ID.
    final String primaryTextField = action.primaryTextField;
    // Get primary field's values.
    final List<ValueModel> primaryFieldValues =
        payload.nodeValues[primaryTextField]?.value ?? [];
    // Email ID would be primary field's input value.
    final String emailID =
        primaryFieldValues
            .firstWhereOrNull((value) => value.name == 'inputValue')
            ?.value
            .typedValue<String>() ??
        '';
    // Do nothing if field is empty.
    if (emailID.isEmpty) return;
    // Submit to selected newsletter service.
    switch (action.service) {
      case SubmitActionService.mailchimp:
        submitToMailchimp(context, action as MailchimpSubmitAction, emailID);
    }
  }

  static Future<http.Response> submitToMailchimp(
    BuildContext context,
    MailchimpSubmitAction action,
    String emailID,
  ) async {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get text fields linked to first and last names.
    final String firstNameField = action.firstNameField;
    final String lastNameField = action.lastNameField;
    // Get text fields' values.
    final List<ValueModel> firstNameFieldValues =
        payload.nodeValues[firstNameField]?.value ?? [];
    final List<ValueModel> lastNameFieldValues =
        payload.nodeValues[lastNameField]?.value ?? [];
    // Get first and last names.
    final String firstName =
        firstNameFieldValues
            .firstWhereOrNull((value) => value.name == 'inputValue')
            ?.value
            .typedValue<String>() ??
        '';
    final String lastName =
        lastNameFieldValues
            .firstWhereOrNull((value) => value.name == 'inputValue')
            ?.value
            .typedValue<String>() ??
        '';
    // Map to merge first and last name values with email ID to submit to
    // Mailchimp.
    final mergeFields = {};
    // Add first and last names to [mergeFields] map.
    if (firstName.isNotEmpty) mergeFields.addAll({'FNAME': firstName});
    if (lastName.isNotEmpty) mergeFields.addAll({'LNAME': lastName});
    // Body of API request.
    final Map<String, dynamic> body = {
      'members': [
        {
          'email_address': emailID,
          'status': 'subscribed',
          'merge_fields': mergeFields,
        },
      ],
    };
    // Mailchimp's endpoint to submit data.
    final String url =
        'https://${action.dataCenter}.api.mailchimp.com/3.0/lists/${action.listID}';
    // Headers to authenticate request.
    final Map<String, String> headers = {
      'Authorization': 'auth ${action.apiKey}',
    };
    // Submit data to Mailchimp.
    return makeApiRequest(
      context: context,
      method: HttpMethod.post,
      url: url,
      headers: headers,
      body: body,
    );
  }

  static void setValue(
    BuildContext context,
    SetValueAction action, {
    dynamic internalValue,
    bool notify = true,
  }) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    for (final ValueModel value in action.values) {
      final ValueModel currentValue = payload.nodeValues[action.nodeID]!.value
          .firstWhere((currentValues) => currentValues.name == value.name);
      setValuePerMode(
        context,
        action: action,
        mode: value.mode,
        discrete: () => value,
        notify: notify,
        toggle: value is BoolValue
            ? () {
                return currentValue.copyWith(
                  value: currentValue.value == null
                      ? null
                      : !currentValue.value.typedValue<bool>()!,
                );
              }
            : null,
        syncValue: internalValue == null
            ? null
            : () => currentValue.copyWith(value: internalValue),
      );
    }
  }

  static void setValuePerMode<V extends ValueModel>(
    BuildContext context, {
    required SetValueAction action,
    required SetValueMode mode,
    V Function()? discrete,
    V Function()? toggle,
    V Function()? syncValue,
    bool notify = true,
  }) {
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final List<ValueModel> values =
        codelesslyContext.nodeValues[action.nodeID]!.value;
    // Get new value.
    V? newValue;
    switch (mode) {
      case SetValueMode.discrete:
        // Get new discrete value.
        if (discrete != null) newValue = discrete();
      case SetValueMode.toggle:
        // Get new toggle value.
        if (toggle != null) newValue = toggle();
      case SetValueMode.syncValue:
        // Get new synced value.
        if (syncValue != null) newValue = syncValue();
    }
    if (newValue != null) {
      // Get old value by name.
      final ValueModel oldValue = values.firstWhere(
        (value) => value.name == newValue!.name,
      );
      // Replace old value with new.
      final List<ValueModel> updateValues = [...values]
        ..remove(oldValue)
        ..add(newValue);
      // Update values list.
      codelesslyContext.nodeValues[action.nodeID]!.set(
        updateValues,
        notify: notify,
      );
    }
  }

  static void setVariant(
    BuildContext context,
    SetVariantAction action, {
    bool notify = true,
  }) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get node's values.
    final List<ValueModel> values = payload.nodeValues[action.nodeID]!.value;
    // Get new variant value.
    final ValueModel newValue = StringValue(
      name: 'currentVariantId',
      value: action.variantID,
    );
    // Get old value by name.
    final ValueModel oldValue = values.firstWhere(
      (value) => value.name == newValue.name,
    );
    // Replace old value with new.
    final List<ValueModel> updateValues = [...values]
      ..remove(oldValue)
      ..add(newValue);
    // Update values list.
    payload.nodeValues[action.nodeID]!.set(updateValues, notify: notify);
  }

  /// Substitutes variables in the [template] of a value to set. For list and
  /// map values written as JSON, each JSON value is substituted on its own
  /// (see [PropertyValueDelegate.substituteJsonValue]), so text holding
  /// quotes or newlines can't break the JSON. Everything else is substituted
  /// as text.
  static String substituteNewValue(
    String template,
    VariableType type,
    ScopedValues scopedValues,
  ) {
    if (type.isList || type.isMap) {
      // A whole-value formula such as `${= item}` keeps its list or map.
      final String? expression = FormulaEvaluator.exactExpression(template);
      if (expression != null) {
        final Object? value = PropertyValueDelegate.evaluateFormula(
          expression,
          scopedValues: scopedValues,
        );
        if (value is List || value is Map) {
          return jsonEncode(
            value,
            toEncodable: (value) =>
                value is DateTime ? value.toIso8601String() : value.toString(),
          );
        }
      }
      final Object? parsed = tryJsonDecode(template.trim());
      if (parsed is List || parsed is Map) {
        return jsonEncode(
          PropertyValueDelegate.substituteJsonValue(parsed, scopedValues),
          toEncodable: (value) =>
              value is DateTime ? value.toIso8601String() : value.toString(),
        );
      }
    }
    return PropertyValueDelegate.substituteVariables(
      template,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );
  }

  /// Sets given [action.newValue] for given [action.variable] to a variable
  /// from [CodelesslyContext.variables].
  /// Returns `true` if variable was found and updated, `false` otherwise.
  static bool setVariableFromAction(
    BuildContext context,
    SetVariableAction action, {
    bool notify = true,
  }) {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final variableNotifier = codelesslyContext.findVariable(
      id: action.variable.id,
      name: action.variable.name,
    );
    if (variableNotifier == null) return false;
    // A computed variable's value comes from its formula: setting it does
    // nothing.
    if (variableNotifier.value.isComputed) {
      DebugLogger.instance.printInfo(
        'Variable ${variableNotifier.value.name} is computed from a formula '
        'and cannot be set.',
        name: name,
      );
      return false;
    }

    String newValue = substituteNewValue(
      action.newValue,
      variableNotifier.value.type,
      scopedValues,
    );

    Object? currentValue = variableNotifier.value.getValue();

    final Object? updatedValue = switch (variableNotifier.value.type) {
      VariableType.text || VariableType.choice => newValue,
      VariableType.image => newValue,
      VariableType.color => ColorRGBA.fromHex(newValue),
      VariableType.integer => _performIntOperation(
        action.numberOperation,
        currentValue?.toInt(),
        newValue,
        scopedValues,
      ),
      VariableType.decimal => _performDecimalOperation(
        action.numberOperation,
        currentValue?.toDouble(),
        newValue,
        scopedValues,
      ),
      VariableType.boolean =>
        action.toggled
            ? !(bool.tryParse(currentValue.toString()) ?? false)
            : bool.tryParse(newValue),
      VariableType.list => _performListOperation(
        action,
        currentValue?.toList(),
        newValue,
        scopedValues,
      ),
      VariableType.map => _performMapOperation(
        action,
        currentValue?.toMap(),
        newValue,
        scopedValues,
      ),
    };

    final VariableData updatedVariable = variableNotifier.value.copyWith(
      value: updatedValue,
    );

    variableNotifier.set(updatedVariable, notify: notify);
    return true;
  }

  /// Sets given [value] for given [id] to a variable from
  /// [CodelesslyContext.variables].
  /// Returns `true` if variable was found and updated, `false` otherwise.
  static bool setVariableValue(
    BuildContext context, {
    required String id,
    required String value,
  }) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();

    final ValueNotifier<VariableData>? variableNotifier = payload.variables[id];
    if (variableNotifier == null) return false;
    if (variableNotifier.value.isComputed) return false;

    variableNotifier.value = variableNotifier.value.copyWith(value: value);

    return true;
  }

  /// Sets given [value] for given [property] of given [node] to a variable
  /// from [CodelesslyContext.variables].
  /// Returns `true` if variable was found and updated, `false` otherwise.
  static bool setPropertyVariable(
    BuildContext context, {
    required BaseNode node,
    required String property,
    required String value,
  }) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();

    final String? variablePath = node.variables[property];

    if (variablePath == null) return false;

    final match = VariableMatch.parse(variablePath.wrapWithVariableSyntax());

    if (match == null) return false;

    final ValueNotifier<VariableData>? propertyNotifier = payload
        .findVariableByName(match.name);

    if (propertyNotifier == null) return false;
    if (propertyNotifier.value.isComputed) return false;

    if (match.name != match.fullPath &&
        (propertyNotifier.value.type == VariableType.map ||
            propertyNotifier.value.type == VariableType.list)) {
      // TODO: support sub path on the variable?
      // sub path on the variable
      propertyNotifier.value = propertyNotifier.value.copyWith(value: value);
      return true;
    }

    propertyNotifier.value = propertyNotifier.value.copyWith(value: value);

    return true;
  }

  /// Sets given [value] to given [property] of given [node] as node value from
  /// [CodelesslyContext.nodeValues].
  /// Returns `true` if node value was found and updated, `false` otherwise.
  static bool setNodeValue(
    BuildContext context, {
    required BaseNode node,
    required String property,
    required dynamic value,
  }) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();

    if (payload.nodeValues[node.id] == null) return false;

    final List<ValueModel> values = payload.nodeValues[node.id]?.value ?? [];
    final ValueModel? valueModel = values.firstWhereOrNull(
      (val) => val.name == property,
    );

    if (valueModel == null) return false;

    final List<ValueModel> updatedValues = [...values]
      ..remove(valueModel)
      ..add(valueModel.copyWith(value: value));

    // DataUtils.nodeValues[node.id]!.value = updatedValues;
    payload.nodeValues[node.id]!.value = updatedValues;

    return true;
  }

  /// Sets given [value] to given [property] of given [node]. If a variable
  /// exists for given [property], it will set the variable's value, otherwise,
  /// it will set the node value.
  /// Returns `true` if variable or node value was found and updated, `false` otherwise.
  static bool setPropertyValue(
    BuildContext context, {
    required BaseNode node,
    required String property,
    required dynamic value,
  }) {
    return setPropertyVariable(
          context,
          node: node,
          property: property,
          value: value.toString(),
        ) ||
        setNodeValue(context, node: node, property: property, value: value);
  }

  /// Triggers actions on given [node] or [reactions] with given [type].
  /// Returns `true` if any action was triggered, `false` otherwise.
  /// If [reactions] is not provided, it will use [node]'s reactions.
  /// If [value] is provided, it will be passed to the action.
  static Future<bool> triggerAction(
    BuildContext context,
    TriggerType type, {
    ReactionMixin? node,
    dynamic value,
    List<Reaction>? reactions,
    Object? result,
  }) async {
    final filteredReactions = (reactions ?? node?.reactions ?? []).where(
      (reaction) => reaction.trigger.type == type,
    );

    if (filteredReactions.isEmpty) return false;

    // A debounced trigger runs once, after the last of a burst.
    final int debounceMs = filteredReactions
        .map((reaction) => reaction.trigger.debounceMs)
        .fold(0, (a, b) => a > b ? a : b);
    if (debounceMs > 0) {
      final Object key = (node ?? reactions ?? context, type);
      _debounceTimers.remove(key)?.cancel();
      final Completer<bool> done = Completer<bool>();
      _debounceTimers[key] = Timer(Duration(milliseconds: debounceMs), () {
        _debounceTimers.remove(key);
        if (!context.mounted) return done.complete(false);
        done.complete(
          ActionChain.run(
            () => _runReactions(context, filteredReactions, value),
            context: context,
          ),
        );
      });
      return done.future;
    }

    // The chain captures the trigger's scope and host now, so its actions
    // read the item that was tapped and still run if the row unmounts.
    // [result] is what `${result}` starts as, e.g. a drag's deltas.
    return ActionChain.run(
      () => _runReactions(context, filteredReactions, value),
      context: context,
      result: result,
    );
  }

  /// The pending runs of debounced triggers, by target and trigger type.
  static final Map<Object, Timer> _debounceTimers = {};

  static Future<bool> _runReactions(
    BuildContext context,
    Iterable<Reaction> filteredReactions,
    dynamic value,
  ) async {
    for (final reaction in filteredReactions) {
      // [context] may have unmounted while the previous action ran; the
      // chain then runs on with another of its contexts.
      final BuildContext? actionContext = _chainContext(
        // ignore: use_build_context_synchronously
        context,
        reaction.action,
      );
      if (actionContext == null || !actionContext.mounted) return true;
      final FutureOr future;
      try {
        future = FunctionsRepository.performAction(
          actionContext,
          reaction.action,
          internalValue: value,
        );
      } catch (e, stackTrace) {
        _reportActionError(reaction, e, stackTrace);
        return true;
      }
      if (!reaction.action.nonBlocking) {
        // Await only if this action is not a non-blocking. It must not be
        // awaited if it is non-blocking. A failed action stops the chain,
        // since later actions usually depend on it.
        try {
          await future;
        } catch (e, stackTrace) {
          _reportActionError(reaction, e, stackTrace);
          return true;
        }
      } else {
        DebugLogger.instance.printInfo(
          'Skipping awaiting for action ${reaction.name} as it is non-blocking...',
          name: name,
        );
        if (future is Future) {
          unawaited(
            future.then<void>(
              (_) {},
              onError: (Object e, StackTrace stackTrace) =>
                  _reportActionError(reaction, e, stackTrace),
            ),
          );
        }
      }
    }

    return true;
  }

  /// The mounted context to run [action] of the current chain with (see
  /// [ActionChain.contextFor]), or null after reporting that the chain
  /// stopped because every context it could use has unmounted.
  static BuildContext? _chainContext(BuildContext context, ActionModel action) {
    final BuildContext? actionContext = ActionChain.contextFor(context);
    if (actionContext == null) {
      ActionChain.reportDetached(
        'Action ${action.type.name} and the ones after it',
      );
    }
    return actionContext;
  }

  static void _reportActionError(
    Reaction reaction,
    Object error,
    StackTrace stackTrace,
  ) {
    ErrorLogger.instance.captureException(
      error,
      message: 'Action ${reaction.name} failed',
      type: 'action_failed',
      stackTrace: stackTrace,
    );
  }

  /// Calls the app's function named by [action], returning its result so
  /// callers can wait for it and see its errors.
  static FutureOr<void> callFunction(
    BuildContext context,
    CallFunctionAction action,
  ) {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final CodelesslyFunction? function =
        codelesslyContext.functions[action.name];

    // Substitute variables in params.
    final Map<String, dynamic> parsedParams = substituteVariablesInMap(
      action.params,
      scopedValues,
    );

    DebugLogger.instance.printInfo(
      'Calling function ${action.name}(${parsedParams.entries.map((e) => '${e.key}: ${e.value}').join(', ')}).',
      name: name,
    );

    return function?.call(
      context,
      codelesslyContext,
      Map.unmodifiable(parsedParams),
    );
  }

  static Future<bool> setStorageFromAction(
    BuildContext context,
    SetStorageAction action,
  ) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    return await switch (action.operation) {
      StorageOperation.addOrUpdate => _updateStorage(action, scopedValues),
      StorageOperation.remove => _removeFromStorage(action, scopedValues),
      StorageOperation.clear => _clearStorage(action, scopedValues),
    };
  }

  static Future<bool> _clearStorage(
    SetStorageAction action,
    ScopedValues scopedValues,
  ) async {
    try {
      final LocalDatabase? storage = scopedValues.localStorage;
      if (storage == null) {
        DebugLogger.instance.printInfo('Storage is null.', name: name);
        return false;
      }
      await storage.clear();
      return true;
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  static Future<bool> _updateStorage(
    SetStorageAction action,
    ScopedValues scopedValues,
  ) async {
    try {
      final LocalDatabase? storage = scopedValues.localStorage;

      if (storage == null) {
        DebugLogger.instance.printInfo('Storage is null.', name: name);
        return false;
      }

      final storageKey = PropertyValueDelegate.substituteVariables(
        action.key,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      final newValue = substituteNewValue(
        action.newValue,
        action.variableType,
        scopedValues,
      );

      final match = VariableMatch.parse(storageKey.wrapWithVariableSyntax());

      final Object? currentValue;
      JsonPointer? pointer;
      if (match != null && match.hasPathOrAccessor) {
        (currentValue, pointer) = PropertyValueDelegate.substituteJsonPath(
          storageKey.wrapWithVariableSyntax(),
          {match.name: storage.get(match.name)},
        );
        if (pointer == null) {
          // This means the key path does not exist.
          final pointerPath = storageKey.toJsonPointerPath();
          pointer = JsonPointer(pointerPath);
        }
      } else {
        currentValue = storage.get(storageKey);
      }

      if (currentValue != null && action.skipIfAlreadyExists) {
        DebugLogger.instance.printInfo(
          'Storage key [$storageKey] already exists. Skipping.',
          name: name,
        );
        return false;
      }

      final Object? value = switch (action.variableType) {
        VariableType.text || VariableType.choice => newValue,
        VariableType.image => newValue,
        VariableType.color => ColorRGBA.fromHex(newValue),
        VariableType.integer => _performIntOperation(
          action.numberOperation,
          currentValue?.toInt(),
          newValue,
          scopedValues,
        ),
        VariableType.decimal => _performDecimalOperation(
          action.numberOperation,
          currentValue?.toDouble(),
          newValue,
          scopedValues,
        ),
        VariableType.boolean =>
          action.toggled
              ? !(bool.tryParse(currentValue.toString()) ?? false)
              : bool.tryParse(newValue),
        VariableType.list => _performListOperation(
          action,
          currentValue?.toList(),
          newValue,
          scopedValues,
        ),
        VariableType.map => _performMapOperation(
          action,
          currentValue?.toMap(),
          newValue,
          scopedValues,
        ),
      };

      if (match == null || pointer == null) {
        // This means the key is a simple key without any path or accessor. So
        // we can set it directly.

        DebugLogger.instance.printInfo(
          '[_updateStorage 1] Setting storage key [$storageKey] to value [$value].',
          name: name,
        );
        await storage.put(storageKey, value);
        return false;
      }

      final defaultValue = action.variableType.isList
          ? []
          : action.variableType.isMap
          ? {}
          : null;
      Map<String, dynamic> storageData = {
        match.name: storage.get(match.name, defaultValue: defaultValue),
      };

      final result = pointer.write(storageData, value);
      if (result != null) {
        storageData = Map<String, dynamic>.from(result as Map);
      }

      DebugLogger.instance.printInfo(
        '[_updateStorage 2] Setting storage key [$storageKey] to value [$value].',
        name: name,
      );
      await storage.put(match.name, storageData[match.name]);

      return true;
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  /// Performs remove operation on given storage [action] and returns `true` if
  /// the operation was successful, `false` otherwise.
  static Future<bool> _removeFromStorage(
    SetStorageAction action,
    ScopedValues scopedValues,
  ) async {
    try {
      final LocalDatabase? storage = scopedValues.localStorage;
      if (storage == null) {
        DebugLogger.instance.printInfo('Storage is null.', name: name);
        return false;
      }

      final storageKey = PropertyValueDelegate.substituteVariables(
        action.key,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      final match = VariableMatch.parse(storageKey.wrapWithVariableSyntax());
      if (match == null || !match.hasPathOrAccessor) {
        // This means the key is a simple key without any path or accessor. So
        // we can remove it directly.
        await storage.remove(storageKey);
        DebugLogger.instance.printInfo(
          'Removed storage key [$storageKey].',
          name: name,
        );
        return true;
      }

      // The key is a json path so we need to remove partial information from
      // a nested path.
      final pointerPath = storageKey.toJsonPointerPath();
      final pointer = JsonPointer(pointerPath);

      Map<String, dynamic> storageData = {match.name: storage.get(match.name)};

      final result = pointer.remove(storageData);
      if (result != null) {
        storageData = Map<String, dynamic>.from(result as Map);
      }

      DebugLogger.instance.printInfo(
        'Removed storage key [$storageKey].',
        name: name,
      );
      await storage.put(match.name, storageData[match.name]);

      return true;
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  static Map? _performMapOperation(
    DataOperationInterface action,
    Map? currentValue,
    String newValue,
    ScopedValues scopedValues,
  ) {
    // If list variable does not exist, return false.
    currentValue ??= {};

    final String substitutedKey = PropertyValueDelegate.substituteVariables(
      action.mapKey,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );

    // Perform map operations.
    switch (action.mapOperation) {
      case MapOperation.add:
        currentValue.addAll(newValue.toMap() ?? {});
      case MapOperation.remove:
        currentValue.remove(substitutedKey);
      case MapOperation.update:
        currentValue[substitutedKey] = newValue.parsedValue();
      case MapOperation.replace:
      case MapOperation.set:
        currentValue = newValue.toMap() ?? {};
    }
    return currentValue;
  }

  static List? _performListOperation(
    DataOperationInterface action,
    List? currentValue,
    String newValue,
    ScopedValues scopedValues,
  ) {
    // If list variable does not exist, return false.
    currentValue ??= [];

    currentValue = [...currentValue];

    // Try to parse index if it's an integer. Else, try to use the variable's
    // value.
    final String substitutedIndex = PropertyValueDelegate.substituteVariables(
      action.index,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );
    final index = int.tryParse(substitutedIndex);
    if (index == null) {
      DebugLogger.instance.printInfo(
        'Invalid index: $substitutedIndex',
        name: name,
      );
      return currentValue;
    }

    // Perform list operations.
    switch (action.listOperation) {
      case ListOperation.add:
        final parsedValue = newValue.toList<List>() ?? [];
        currentValue.addAll(parsedValue);
      case ListOperation.insert:
        currentValue.insert(index, newValue.parsedValue());
      case ListOperation.insertAll:
        final parsedValue = newValue.toList<List>() ?? [];
        currentValue.insertAll(index, parsedValue);
      case ListOperation.removeAt:
        currentValue.removeAt(index);
      case ListOperation.remove:
        currentValue.removeWhere((element) => element.toString() == newValue);
      case ListOperation.update:
        final parsedValue = newValue.parsedValue();
        if (currentValue.length > index) {
          currentValue[index] = parsedValue;
        } else if (currentValue.length == index) {
          currentValue.add(parsedValue);
        }
      case ListOperation.set:
      case ListOperation.replace:
        final parsedValue = newValue.toList<List>() ?? [];
        return parsedValue;
    }
    return currentValue;
  }

  static Future<bool> setCloudDatabaseFromAction(
    BuildContext context,
    SetCloudStorageAction action,
  ) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    await awaitCloudDatabase(context);
    return await switch (action.subAction) {
      AddDocumentSubAction addDocumentSubAction => addDocumentToCloud(
        addDocumentSubAction,
        scopedValues,
      ),
      UpdateDocumentSubAction updateDocumentSubAction => updateDocumentOnCloud(
        updateDocumentSubAction,
        scopedValues,
      ),
      RemoveDocumentSubAction removeDocumentSubAction =>
        removeDocumentFromCloud(removeDocumentSubAction, scopedValues),
      RemoveDocumentsSubAction subAction => removeDocumentsFromCloud(
        subAction,
        scopedValues,
      ),
      SetDocumentsSubAction subAction => setDocumentsOnCloud(
        subAction,
        scopedValues,
      ),
    };
  }

  /// The value [template] gives: a value as is when it is exactly one
  /// `${...}` path or formula, else its text with variables substituted,
  /// decoded when it is JSON (whose strings may hold paths too).
  static Object? _valueFromTemplate(
    String template,
    ScopedValues scopedValues,
  ) {
    final String trimmed = template.trim();
    if (trimmed.isEmpty) return null;
    if (FormulaEvaluator.exactExpression(trimmed) != null ||
        RegExp(r'^\$\{[^{}]+\}$').hasMatch(trimmed)) {
      return PropertyValueDelegate.getVariableValueFromPath<Object>(
        trimmed,
        scopedValues: scopedValues,
      );
    }
    final Object? json = tryJsonDecode(trimmed);
    if (json is List || json is Map) {
      return PropertyValueDelegate.substituteJsonValue(json, scopedValues);
    }
    return PropertyValueDelegate.substituteVariables(
      trimmed,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
  }

  /// Document ids from [value]: a list of ids or of documents (their `id`),
  /// JSON text of one, or ids separated by commas.
  @visibleForTesting
  static List<String> documentIdsOf(Object? value) {
    if (value is String) {
      final Object? json = tryJsonDecode(value.trim());
      if (json is List) return documentIdsOf(json);
      return [
        for (final String id in value.split(','))
          if (id.trim().isNotEmpty) id.trim(),
      ];
    }
    if (value is Iterable) {
      return [
        for (final Object? item in value)
          if (item is Map
              ? item['id'] != null
              : item != null && item.toString().trim().isNotEmpty)
            (item is Map ? item['id'] : item).toString().trim(),
      ];
    }
    if (value is Map && value['id'] != null) return [value['id'].toString()];
    return [];
  }

  /// Removes many documents in one batched write: those [documentIds] gives,
  /// or those matching the where filters (all of the collection when there
  /// are none). `${result.count}` is how many were removed.
  ///
  /// [database] stands in for the app's cloud database, in tests.
  static Future<bool> removeDocumentsFromCloud(
    RemoveDocumentsSubAction subAction,
    ScopedValues scopedValues, {
    @visibleForTesting CloudDatabase? database,
  }) async {
    try {
      final CloudDatabase? cloudDatabase =
          database ?? scopedValues.cloudDatabase;
      if (cloudDatabase is! FirestoreCloudDatabase) {
        DebugLogger.instance.printInfo(
          'Batch removal requires a Firestore cloud database.',
          name: name,
        );
        return false;
      }
      final String path = PropertyValueDelegate.substituteVariables(
        subAction.path,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );
      final List<String>? ids = subAction.documentIds.trim().isEmpty
          ? null
          : documentIdsOf(
              _valueFromTemplate(subAction.documentIds, scopedValues),
            );
      if (ids != null && ids.isEmpty) {
        DebugLogger.instance.printInfo(
          'No valid document ids supplied.',
          name: name,
        );
        return false;
      }
      // The database's by-ID batch path does not check ownership. Its query
      // path does, so refuse by-ID deletion for owner-scoped collections.
      if (ids != null && cloudDatabase.rules.ruleFor(path).readsOwnOnly) {
        DebugLogger.instance.printInfo(
          'Batch removal by id cannot verify document ownership.',
          name: name,
        );
        return false;
      }
      final List<CloudWhereFilter> filters = ids != null
          ? const []
          : resolveCloudQuery(
              whereFilters: subAction.whereFilters,
              orderByOperations: const [],
              scopedValues: scopedValues,
              nullSubstitutionMode: NullSubstitutionMode.emptyString,
            ).filters;
      final int removed = await cloudDatabase.removeDocuments(
        path,
        documentIds: ids,
        filters: filters,
      );
      ActionChain.setResult({'count': removed, 'path': path});
      return true;
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  /// Writes a list of documents in one batched write, e.g. seed data from a
  /// list variable. `${result.count}` is how many were written.
  ///
  /// [database] stands in for the app's cloud database, in tests.
  static Future<bool> setDocumentsOnCloud(
    SetDocumentsSubAction subAction,
    ScopedValues scopedValues, {
    @visibleForTesting CloudDatabase? database,
  }) async {
    try {
      final CloudDatabase? cloudDatabase =
          database ?? scopedValues.cloudDatabase;
      if (cloudDatabase is! FirestoreCloudDatabase) {
        DebugLogger.instance.printInfo(
          'Batch writes require a Firestore cloud database.',
          name: name,
        );
        return false;
      }
      final String path = PropertyValueDelegate.substituteVariables(
        subAction.path,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );
      Object? value = _valueFromTemplate(subAction.documents, scopedValues);
      if (value is String) value = tryJsonDecode(value);
      if (value is Map) value = [value];
      if (value is! List) {
        DebugLogger.instance.printInfo(
          'Set Documents needs a list of documents, got $value.',
          name: name,
        );
        return false;
      }
      if (value.any((item) => item is! Map)) {
        DebugLogger.instance.printInfo(
          'Set Documents requires every entry to be a document map.',
          name: name,
        );
        return false;
      }
      final List<Map<String, dynamic>> documents = [
        for (final Object? item in value)
          Map<String, dynamic>.from(item as Map),
      ];
      final String idField = subAction.idField.trim().isEmpty
          ? 'id'
          : subAction.idField.trim();
      final int written = await cloudDatabase.setDocuments(
        path,
        documents,
        idField: idField,
        merge: subAction.merge,
        replaceCollection: subAction.replaceCollection,
      );
      ActionChain.setResult({'count': written, 'path': path});
      return true;
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  static Future<bool> addDocumentToCloud(
    AddDocumentSubAction subAction,
    ScopedValues scopedValues,
  ) async {
    try {
      final CloudDatabase? cloudDatabase = scopedValues.cloudDatabase;

      if (cloudDatabase == null) {
        DebugLogger.instance.printInfo('Cloud storage is null.', name: name);
        return false;
      }

      final evaluatedPath = PropertyValueDelegate.substituteVariables(
        subAction.path,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );
      final evaluatedDocumentId = PropertyValueDelegate.substituteVariables(
        subAction.documentId,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      Map<String, dynamic> data = {};
      if (subAction.useRawValue) {
        data = _jsonFromTemplate(subAction.rawValue, scopedValues);
      } else {
        data = _jsonFromTemplate(subAction.newValue, scopedValues);
      }

      // Pick the id here when generating one, so `${result.id}` can tell the
      // following actions which document was added.
      final String documentId = subAction.autoGenerateId
          ? generateId()
          : evaluatedDocumentId;
      final bool added = await cloudDatabase.addDocument(
        evaluatedPath,
        value: data,
        documentId: documentId,
        skipCreationIfDocumentExists:
            !subAction.autoGenerateId && subAction.skipCreationIfDocumentExists,
      );
      ActionChain.setResult({'id': documentId, 'path': evaluatedPath});
      return added;
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  /// The document data a JSON [template] describes once its variables are
  /// substituted. See [PropertyValueDelegate.substituteVariablesInJson].
  static Map<String, dynamic> _jsonFromTemplate(
    String template,
    ScopedValues scopedValues,
  ) {
    final Map<String, dynamic>? data =
        PropertyValueDelegate.substituteVariablesInJson(
          template,
          scopedValues: scopedValues,
        );
    if (data != null) return data;
    final Object? parsed = tryJsonDecode(
      PropertyValueDelegate.substituteVariables(
        template,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      ),
    );
    return switch (parsed) {
      null => {},
      Map map => Map<String, dynamic>.from(map),
      _ => {'data': parsed},
    };
  }

  static Future<bool> updateDocumentOnCloud(
    UpdateDocumentSubAction subAction,
    ScopedValues scopedValues,
  ) async {
    final CloudDatabase? cloudDatabase = scopedValues.cloudDatabase;

    if (cloudDatabase == null) {
      DebugLogger.instance.printInfo('Cloud storage is null.', name: name);
      return false;
    }

    final evaluatedPath = PropertyValueDelegate.substituteVariables(
      subAction.path,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );
    final evaluatedDocumentId = PropertyValueDelegate.substituteVariables(
      subAction.documentId,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );

    if (subAction.useRawValue) {
      final Map<String, dynamic> data = _jsonFromTemplate(
        subAction.rawValue,
        scopedValues,
      );

      return await cloudDatabase.updateDocument(
        evaluatedPath,
        documentId: evaluatedDocumentId,
        value: data,
      );
    }

    try {
      final storageKey = PropertyValueDelegate.substituteVariables(
        subAction.key,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      final newValue = PropertyValueDelegate.substituteVariables(
        subAction.newValue,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      final match = VariableMatch.parse(storageKey.wrapWithVariableSyntax());
      final docData = await cloudDatabase.getDocumentData(
        subAction.path,
        evaluatedDocumentId,
      );

      final Object? currentValue;
      JsonPointer? pointer;
      if (match != null && match.hasPathOrAccessor) {
        (currentValue, pointer) = PropertyValueDelegate.substituteJsonPath(
          storageKey.wrapWithVariableSyntax(),
          {match.name: docData[match.name]},
        );
        if (pointer == null) {
          // This means the key path does not exist.
          final pointerPath = storageKey.toJsonPointerPath();
          pointer = JsonPointer(pointerPath);
        }
      } else {
        currentValue = docData[storageKey];
      }

      // if (!context.mounted) throw Exception('Context is not mounted.');

      final Object? value = switch (subAction.variableType) {
        VariableType.text || VariableType.choice => newValue,
        VariableType.image => newValue,
        VariableType.color => ColorRGBA.fromHex(newValue),
        VariableType.integer => _performIntOperation(
          subAction.numberOperation,
          currentValue?.toInt(),
          newValue,
          scopedValues,
        ),
        VariableType.decimal => _performDecimalOperation(
          subAction.numberOperation,
          currentValue?.toDouble(),
          newValue,
          scopedValues,
        ),
        VariableType.boolean =>
          subAction.toggled
              ? !(bool.tryParse(currentValue.toString()) ?? false)
              : bool.tryParse(newValue),
        VariableType.list => _performListOperation(
          subAction,
          currentValue?.toList(),
          newValue,
          scopedValues,
        ),
        VariableType.map => _performMapOperation(
          subAction,
          currentValue?.toMap(),
          newValue,
          scopedValues,
        ),
      };

      if (match == null || pointer == null) {
        // This means the key is a simple key without any path or accessor. So
        // we can set it directly.

        DebugLogger.instance.printInfo(
          '[updateDocumentOnCloud 1] Setting storage key [$storageKey] to value [$value].',
          name: name,
        );
        docData[storageKey] = value;
        return await cloudDatabase.updateDocument(
          evaluatedPath,
          documentId: evaluatedDocumentId,
          // Update only the field that was changed.
          value: {storageKey: docData[storageKey]},
        );
      }

      final defaultValue = subAction.variableType.isList
          ? []
          : subAction.variableType.isMap
          ? {}
          : null;
      Map<String, dynamic> storageData = {
        match.name: docData[match.name] ?? defaultValue,
      };

      final result = pointer.write(storageData, value);
      if (result != null) {
        storageData = Map<String, dynamic>.from(result as Map);
      }

      DebugLogger.instance.printInfo(
        '[updateDocumentOnCloud 2] Setting storage key [$storageKey] to value [$value].',
        name: name,
      );
      docData[match.name] = storageData[match.name];

      return await cloudDatabase.updateDocument(
        evaluatedPath,
        documentId: evaluatedDocumentId,
        // Update only the field that was changed.
        value: {match.name: docData[match.name]},
      );
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  static Future<bool> removeDocumentFromCloud(
    RemoveDocumentSubAction subAction,
    ScopedValues scopedValues,
  ) async {
    try {
      final CloudDatabase? cloudDatabase = scopedValues.cloudDatabase;

      if (cloudDatabase == null) {
        DebugLogger.instance.printInfo('Cloud storage is null.', name: name);
        return false;
      }

      final evaluatedPath = PropertyValueDelegate.substituteVariables(
        subAction.path,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );
      final evaluatedDocumentId = PropertyValueDelegate.substituteVariables(
        subAction.documentId,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      return await cloudDatabase.removeDocument(
        evaluatedPath,
        evaluatedDocumentId,
      );
    } catch (error, stackTrace) {
      DebugLogger.instance.printInfo(error.toString(), name: name);
      DebugLogger.instance.printInfo(stackTrace.toString(), name: name);
      return false;
    }
  }

  /// The project's cloud database, waiting for it when an action runs
  /// before it is ready: on a reload the app user is restored, and a screen
  /// can load data, before the SDK has verified the project's data access.
  static Future<CloudDatabase?> awaitCloudDatabase(
    BuildContext context, {
    Codelessly? codelessly,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    codelessly ??= context.read<Codelessly>();
    final DateTime deadline = DateTime.now().add(timeout);
    while (codelessly.cloudDatabase == null &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return codelessly.cloudDatabase;
  }

  static Future<void> loadFromStorageAction(
    BuildContext context,
    LoadFromCloudStorageAction action,
  ) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);

    final evaluatedPath = PropertyValueDelegate.substituteVariables(
      action.path,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );

    Observable<VariableData>? variable;
    if (action.variable != null) {
      // Find a variable for the api and pass it.
      // This makes it so the same variable for the api gets updated. This
      // helps updating UI with new data.
      final codelesslyContext = context.read<CodelesslyContext>();
      variable = codelesslyContext.findVariableByName(action.variable!.name);
    }

    if (variable == null) return;

    // set loading
    variable.value = variable.value.copyWith(
      value: CloudDatabaseVariableUtils.loading(),
    );

    final Codelessly codelessly = context.read<Codelessly>();
    final CloudDatabase? cloudDatabase =
        scopedValues.cloudDatabase ??
        await awaitCloudDatabase(context, codelessly: codelessly);

    if (cloudDatabase == null) {
      DebugLogger.instance.printInfo(
        'Cloud storage did not initialize.',
        name: name,
      );
      variable.value = variable.value.copyWith(
        value: CloudDatabaseVariableUtils.error('Cloud data is unavailable.'),
      );
      return;
    }

    if (action.loadSingleDocument) {
      final evaluatedDocumentId = PropertyValueDelegate.substituteVariables(
        action.documentId,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );
      DebugLogger.instance.printInfo(
        'Streaming document from cloud storage: $evaluatedPath/$evaluatedDocumentId',
        name: name,
      );
      await cloudDatabase.streamDocumentToVariable(
        evaluatedPath,
        evaluatedDocumentId,
        variable,
      );
    } else {
      DebugLogger.instance.printInfo(
        'Streaming collection from cloud storage: $evaluatedPath',
        name: name,
      );

      await cloudDatabase.streamCollectionToVariable(
        evaluatedPath,
        variable,
        whereFilters: action.whereFilters,
        orderByOperations: action.orderByFilters,
        limit: (action.limit ?? 0) > 0 ? action.limit : null,
        scopedValues: scopedValues,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      );
    }
  }

  static int? _performIntOperation(
    NumberOperation numberOperation,
    int? currentValue,
    String newValue,
    ScopedValues scopedValues,
  ) {
    final String substitutedValue = PropertyValueDelegate.substituteVariables(
      newValue,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );

    final int? parsedValue = int.tryParse(substitutedValue);

    if (parsedValue == null) {
      DebugLogger.instance.printInfo(
        'Invalid value: $substitutedValue',
        name: name,
      );
      return currentValue;
    }

    currentValue ??= 0;

    return switch (numberOperation) {
      NumberOperation.set => parsedValue,
      NumberOperation.add => currentValue + parsedValue,
      NumberOperation.subtract => currentValue - parsedValue,
    };
  }

  static double? _performDecimalOperation(
    NumberOperation numberOperation,
    double? currentValue,
    String newValue,
    ScopedValues scopedValues,
  ) {
    final String substitutedValue = PropertyValueDelegate.substituteVariables(
      newValue,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );

    final double? parsedValue = double.tryParse(substitutedValue);

    if (parsedValue == null) {
      DebugLogger.instance.printInfo(
        'Invalid value: $substitutedValue',
        name: name,
      );
      return currentValue;
    }

    currentValue ??= 0;

    return switch (numberOperation) {
      NumberOperation.set => parsedValue,
      NumberOperation.add => currentValue + parsedValue,
      NumberOperation.subtract => currentValue - parsedValue,
    };
  }
}
