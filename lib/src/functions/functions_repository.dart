import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rfc_6901/rfc_6901.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../codelessly_sdk.dart';
import '../ui/codelessly_dialog_widget.dart';

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

const String _label = 'Functions Repository';

class FunctionsRepository {
  static void _log(String message, {bool largePrint = false}) =>
      logger.log(_label, message, largePrint: largePrint);

  // Avoid using this method directly in favor of [triggerAction] if possible.
  static FutureOr performAction(
    BuildContext context,
    ActionModel action, {
    dynamic internalValue,
    bool notify = true,
  }) {
    if (!action.enabled) {
      _log('Action ${action.type} is disabled. Skipping...');
      return true;
    }
    _log('Performing action: $action');
    switch (action.type) {
      case ActionType.navigation:
        return navigate(context, action as NavigationAction);
      case ActionType.showDialog:
        return showDialogAction(context, action as ShowDialogAction);
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
        return setVariableFromAction(context, action as SetVariableAction,
            notify: notify);
      case ActionType.callFunction:
        callFunction(context, action as CallFunctionAction);
        return true;
      case ActionType.callApi:
        return makeApiRequestFromAction(action as ApiCallAction, context);
      case ActionType.setStorage:
        return setStorageFromAction(context, action as SetStorageAction);
      case ActionType.setCloudStorage:
        return setCloudDatabaseFromAction(
            context, action as SetCloudStorageAction);
      case ActionType.loadFromCloudStorage:
        return loadFromStorageAction(
            context, action as LoadFromCloudStorageAction);
    }
  }

  static Future<http.Response> makeApiRequestFromAction(
    ApiCallAction action,
    BuildContext context, [
    Observable<VariableData>? variable,
  ]) {
    final Map<String, HttpApiData> apis =
        context.read<Codelessly>().dataManager.publishModel!.apis;

    final HttpApiData? apiData = apis[action.apiId];

    final Codelessly codelessly = context.read<Codelessly>();

    if (apiData == null) {
      codelessly.errorHandler.captureException(
        CodelesslyException.apiNotFound(
          apiId: action.apiId,
          message: 'Api with id [${action.apiId}] does not exist.',
          layoutID: context.read<CodelesslyWidgetController>().layoutID,
        ),
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
      final paramValue =
          param != null && param.value.isNotEmpty ? param.value : '';
      params[name] = paramValue;
    }

    final ScopedValues scopedValues = ScopedValues.of(context);

    return makeApiRequest(
      context: context,
      method: apiData.method,
      url: _applyApiInputs(apiData.url, params, scopedValues),
      headers: _generateMapFromPairs(apiData.headers, params, scopedValues),
      body: apiData.bodyType == RequestBodyType.form
          ? _generateMapFromPairs(apiData.formFields, params, scopedValues)
          : _applyApiInputs(apiData.body ?? '', params, scopedValues),
      variable: variable,
    );
  }

  static Map<String, String> _generateMapFromPairs(List<HttpKeyValuePair> pairs,
      Map<String, String> parameters, ScopedValues scopedValues) {
    return pairs
        .where((pair) => pair.isUsed && pair.key.isNotEmpty)
        .toList()
        .asMap()
        .map((key, pair) => MapEntry(
            _applyApiInputs(pair.key, parameters, scopedValues),
            _applyApiInputs(pair.value, parameters, scopedValues)));
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
        _log('parameter ${match.group(1)} not found');
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
    NavigationAction action,
  ) async {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final parsedParams = substituteVariablesInMap(action.params, scopedValues);

    _log('Performing navigation action with params: $parsedParams');

    if (action.navigationType == NavigationType.pop) {
      await Navigator.maybePop(context, parsedParams);
    } else {
      final Codelessly codelessly = context.read<Codelessly>();
      // Check if a layout exists for the action's [destinationId].
      final String? layoutId = codelessly
              .dataManager.publishModel?.layouts[action.destinationId]?.id ??
          codelessly.dataManager.publishModel?.layouts.values
              .firstWhereOrNull(
                  (layout) => layout.canvasIds.contains(action.destinationId))
              ?.id;

      _log('looking for layout with canvas id: [${action.destinationId}]');
      for (final layout
          in codelessly.dataManager.publishModel!.layouts.values) {
        _log(
            'layout [${layout.id}] canvas ids: [${layout.canvasIds.join(', ')}]');
      }

      if (layoutId == null) {
        final Codelessly codelessly = context.read<Codelessly>();
        codelessly.errorHandler.captureException(
          CodelesslyException.layoutNotFound(
            message:
                'Could not find a layout with a canvas id of [${action.destinationId}]',
            layoutID: layoutId,
          ),
        );
        return;
      }

      final parentController = context.read<CodelesslyWidgetController>();
      final effectiveController = parentController.copyWith(
        layoutID: layoutId,
        codelessly: codelessly,
      );

      if (action.navigationType == NavigationType.push) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(arguments: parsedParams),
            builder: (context) => CodelesslyWidget(
              controller: effectiveController,
            ),
          ),
        );
        // ignore: use_build_context_synchronously
        codelessly.notifyNavigationListeners(context);
      } else if (action.navigationType == NavigationType.replace) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            settings: RouteSettings(arguments: parsedParams),
            builder: (context) => CodelesslyWidget(
              controller: effectiveController,
            ),
          ),
        );
        // ignore: use_build_context_synchronously
        codelessly.notifyNavigationListeners(context);
      }
    }
  }

  static Future<void> showDialogAction(
    BuildContext context,
    ShowDialogAction action,
  ) async {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final parsedParams = substituteVariablesInMap(action.params, scopedValues);

    _log('Performing show dialog action with params: $parsedParams');

    final Codelessly codelessly = context.read<Codelessly>();
    // Check if a layout exists for the action's [destinationId].
    final String? layoutId = codelessly.dataManager.publishModel?.layouts.values
        .firstWhereOrNull(
            (layout) => layout.canvasIds.contains(action.destinationId))
        ?.id;

    _log('looking for layout with canvas id: [${action.destinationId}]');
    for (final layout in codelessly.dataManager.publishModel!.layouts.values) {
      _log(
          'layout [${layout.id}] canvas ids: [${layout.canvasIds.join(', ')}]');
    }

    if (layoutId == null) {
      final Codelessly codelessly = context.read<Codelessly>();
      codelessly.errorHandler.captureException(
        CodelesslyException.layoutNotFound(
          message:
              'Could not find a layout with a canvas id of [${action.destinationId}]',
          layoutID: layoutId,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: action.barrierDismissible,
      barrierColor: action.barrierColor?.toFlutterColor(),
      routeSettings: RouteSettings(arguments: parsedParams),
      builder: (context) => CodelesslyDialogWidget(
        showCloseButton: action.showCloseButton,
        builder: (context) => CodelesslyWidget(
          codelessly: codelessly,
          layoutID: layoutId,
        ),
      ),
    );
    // ignore: use_build_context_synchronously
    codelessly.notifyNavigationListeners(context);
  }

  static void launchURL(BuildContext context, LinkAction action) {
    final url = PropertyValueDelegate.substituteVariables(
      action.url,
      nullSubstitutionMode: NullSubstitutionMode.nullValue,
      scopedValues: ScopedValues.of(context),
    );
    launchUrl(Uri.parse(url));
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
    assert(variable == null || variable.value.type.isMap,
        'Provided variable for api call must be of type map. Found ${variable.value.type}');

    printApiDetails(method: method, url: url, headers: headers, body: body);

    // persist previous api call data if there is any. This allows us to
    // show previous data while new data is being fetched.
    final existingData = variable?.value.getValue().typedValue<Map>()?['data'];
    if (variable != null) {
      variable.value = variable.value.copyWith(
        value: ApiResponseVariableUtils.loading(url, data: existingData),
      );
      _log('${variable.value.name} updated with loading state.');
    } else {
      _log('No variable provided for api call.');
    }

    try {
      final http.Response response;
      if (kIsWeb && useCloudFunctionForWeb) {
        final String cloudFunctionsURL =
            context.read<Codelessly>().config!.firebaseCloudFunctionsBaseURL;
        final receivedResponse = await makeApiRequestWeb(
          method: method,
          url: url,
          headers: headers,
          body: body,
          cloudFunctionsURL: cloudFunctionsURL,
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
        final Uri uri = Uri.parse(url);
        response = switch (method) {
          HttpMethod.get => await http.get(uri, headers: headers),
          HttpMethod.post => await http.post(uri, headers: headers, body: body),
          HttpMethod.delete =>
            await http.delete(uri, headers: headers, body: body),
          HttpMethod.put => await http.put(uri, headers: headers, body: body)
        };
      }

      printResponse(response);

      if (variable != null) {
        variable.value = variable.value.copyWith(
          value: ApiResponseVariableUtils.fromResponse(response),
        );
        _log('${variable.value.name} updated with success state.');
      } else {
        _log('No variable provided for api call.');
      }

      return response;
    } catch (error, stackTrace) {
      _log(error.toString());
      _log(stackTrace.toString());
      if (variable != null) {
        variable.value = variable.value.copyWith(
          value: ApiResponseVariableUtils.error(
            url,
            error,
            data: existingData,
          ),
        );
        _log('${variable.value.name} updated with error state.');
      } else {
        _log('No variable provided for api call.');
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
    _log(
        '--------------------------------------------------------------------');
    _log('API Request:');
    _log(
        '--------------------------------------------------------------------');
    _log('${method.shortName} $url');
    _log('Headers: ${headers.isEmpty ? 'None' : ''}');
    if (headers.isNotEmpty) {
      _log(const JsonEncoder.withIndent('  ').convert(headers));
      _log('');
    }
    _log(
        'Body: ${body == null || body.toString().trim().isEmpty ? 'None' : ''}');
    if (body != null && body.toString().trim().isNotEmpty) {
      try {
        final parsed = json.decode(body.toString());
        _log(const JsonEncoder.withIndent('  ').convert(parsed));
      } catch (e) {
        _log(body.toString());
      }
    }
    _log(
        '--------------------------------------------------------------------');
  }

  static void printResponse(http.Response response) {
    if (kReleaseMode) return;
    _log(
      '''
--------------------------------------------------------------------
Response:
--------------------------------------------------------------------
Status Code: ${response.statusCode}
Headers:
${const JsonEncoder.withIndent('  ').convert(response.headers)}

Body:
${response.body.contains('{') ? const JsonEncoder.withIndent('  ').convert(json.decode(response.body)) : response.body}
--------------------------------------------------------------------
''',
      largePrint: true,
    );
  }

  /// Makes API request using cloud function to prevent any CORS issues.
  static Future<http.Response> makeApiRequestWeb({
    required HttpMethod method,
    required String url,
    required Map<String, dynamic> headers,
    required Object? body,
    required String cloudFunctionsURL,
  }) async {
    return http.post(
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
      BuildContext context, SubmitAction action) async {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get primary linked text field ID.
    final String primaryTextField = action.primaryTextField;
    // Get primary field's values.
    final List<ValueModel> primaryFieldValues =
        payload.nodeValues[primaryTextField]?.value ?? [];
    // Email ID would be primary field's input value.
    final String emailID = primaryFieldValues
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
    final String firstName = firstNameFieldValues
            .firstWhereOrNull((value) => value.name == 'inputValue')
            ?.value
            .typedValue<String>() ??
        '';
    final String lastName = lastNameFieldValues
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
        }
      ]
    };
    // Mailchimp's endpoint to submit data.
    final String url =
        'https://${action.dataCenter}.api.mailchimp.com/3.0/lists/${action.listID}';
    // Headers to authenticate request.
    final Map<String, String> headers = {
      'Authorization': 'auth ${action.apiKey}'
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
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
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
      final ValueModel oldValue =
          values.firstWhere((value) => value.name == newValue!.name);
      // Replace old value with new.
      final List<ValueModel> updateValues = [...values]
        ..remove(oldValue)
        ..add(newValue);
      // Update values list.
      codelesslyContext.nodeValues[action.nodeID]!
          .set(updateValues, notify: notify);
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
    final ValueModel newValue =
        StringValue(name: 'currentVariantId', value: action.variantID);
    // Get old value by name.
    final ValueModel oldValue =
        values.firstWhere((value) => value.name == newValue.name);
    // Replace old value with new.
    final List<ValueModel> updateValues = [...values]
      ..remove(oldValue)
      ..add(newValue);
    // Update values list.
    payload.nodeValues[action.nodeID]!.set(updateValues, notify: notify);
  }

  /// Sets given [action.newValue] for given [action.variable] to a variable
  /// from [CodelesslyContext.variables].
  /// Returns `true` if variable was found and updated, `false` otherwise.
  static bool setVariableFromAction(
    BuildContext context,
    SetVariableAction action, {
    bool notify = true,
  }) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    final variableNotifier =
        codelesslyContext.findVariableByName(action.variable.name);
    if (variableNotifier == null) return false;

    String newValue = PropertyValueDelegate.substituteVariables(
      action.newValue,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );

    Object? currentValue = variableNotifier.value.getValue();

    final Object? updatedValue = switch (variableNotifier.value.type) {
      VariableType.text => newValue,
      VariableType.color => ColorRGBA.fromHex(newValue),
      VariableType.integer => _performIntOperation(action.numberOperation,
          currentValue?.toInt(), newValue, scopedValues),
      VariableType.decimal => _performDecimalOperation(action.numberOperation,
          currentValue?.toDouble(), newValue, scopedValues),
      VariableType.boolean => action.toggled
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

    final VariableData updatedVariable =
        variableNotifier.value.copyWith(value: updatedValue);

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

    final ValueNotifier<VariableData>? propertyNotifier =
        payload.findVariableByName(match.name);

    if (propertyNotifier == null) return false;

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
    final ValueModel? valueModel =
        values.firstWhereOrNull((val) => val.name == property);

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
        setNodeValue(
          context,
          node: node,
          property: property,
          value: value,
        );
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
  }) async {
    final filteredReactions = (reactions ?? node?.reactions ?? [])
        .where((reaction) => reaction.trigger.type == type);

    if (filteredReactions.isEmpty) return false;

    for (final reaction in filteredReactions) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) continue;
      final future = FunctionsRepository.performAction(
        context,
        reaction.action,
        internalValue: value,
      );
      if (!reaction.action.nonBlocking) {
        // Await only if this action is not a non-blocking. It must not be
        // awaited if it is non-blocking.
        await future;
      } else {
        _log(
            'Skipping awaiting for action ${reaction.name} as it is non-blocking...');
      }
    }

    return true;
  }

  static void callFunction(BuildContext context, CallFunctionAction action) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    final CodelesslyFunction? function =
        codelesslyContext.functions[action.name];

    // Substitute variables in params.
    final Map<String, dynamic> parsedParams =
        substituteVariablesInMap(action.params, scopedValues);

    _log(
        'Calling function ${action.name}(${parsedParams.entries.map((e) => '${e.key}: ${e.value}').join(', ')}).');

    function?.call(context, codelesslyContext, Map.unmodifiable(parsedParams));
  }

  static Future<bool> setStorageFromAction(
    BuildContext context,
    SetStorageAction action,
  ) async {
    final ScopedValues scopedValues = ScopedValues.of(context);
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
        _log('Storage is null.');
        return false;
      }
      await storage.clear();
      return true;
    } catch (error, stackTrace) {
      _log(error.toString());
      _log(stackTrace.toString());
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
        _log('Storage is null.');
        return false;
      }

      final storageKey = PropertyValueDelegate.substituteVariables(
        action.key,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );

      final newValue = PropertyValueDelegate.substituteVariables(
        action.newValue,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
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
        _log('Storage key [$storageKey] already exists. Skipping.');
        return false;
      }

      final Object? value = switch (action.variableType) {
        VariableType.text => newValue,
        VariableType.color => ColorRGBA.fromHex(newValue),
        VariableType.integer => _performIntOperation(action.numberOperation,
            currentValue?.toInt(), newValue, scopedValues),
        VariableType.decimal => _performDecimalOperation(action.numberOperation,
            currentValue?.toDouble(), newValue, scopedValues),
        VariableType.boolean => action.toggled
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

        _log(
            '[_updateStorage 1] Setting storage key [$storageKey] to value [$value].');
        await storage.put(storageKey, value);
        return false;
      }

      final defaultValue = action.variableType.isList
          ? []
          : action.variableType.isMap
              ? {}
              : null;
      Map<String, dynamic> storageData = {
        match.name: storage.get(match.name, defaultValue: defaultValue)
      };

      final result = pointer.write(storageData, value);
      if (result != null) {
        storageData = Map<String, dynamic>.from(result as Map);
      }

      _log(
          '[_updateStorage 2] Setting storage key [$storageKey] to value [$value].');
      await storage.put(match.name, storageData[match.name]);

      return true;
    } catch (error, stackTrace) {
      _log(error.toString());
      _log(stackTrace.toString());
      return false;
    }
  }

  /// Performs remove operation on given storage [action] and returns `true` if
  /// the operation was successful, `false` otherwise.
  static Future<bool> _removeFromStorage(
      SetStorageAction action, ScopedValues scopedValues) async {
    try {
      final LocalDatabase? storage = scopedValues.localStorage;
      if (storage == null) {
        _log('Storage is null.');
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
        _log('Removed storage key [$storageKey].');
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

      _log('Removed storage key [$storageKey].');
      await storage.put(match.name, storageData[match.name]);

      return true;
    } catch (error, stackTrace) {
      _log(error.toString());
      _log(stackTrace.toString());
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
      _log('Invalid index: $substitutedIndex');
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
    final ScopedValues scopedValues = ScopedValues.of(context);
    return await switch (action.subAction) {
      AddDocumentSubAction action => addDocumentToCloud(action, scopedValues),
      UpdateDocumentSubAction action =>
        updateDocumentOnCloud(action, scopedValues),
      RemoveDocumentSubAction action =>
        removeDocumentFromCloud(action, scopedValues),
    };
  }

  static Future<bool> addDocumentToCloud(
    AddDocumentSubAction subAction,
    ScopedValues scopedValues,
  ) async {
    try {
      final CloudDatabase? cloudDatabase = scopedValues.cloudDatabase;

      if (cloudDatabase == null) {
        _log('Cloud storage is null.');
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
        // Substitute variables in raw value.
        final updatedValue = PropertyValueDelegate.substituteVariables(
          subAction.rawValue,
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
          scopedValues: scopedValues,
        );
        // Parse to JSON.
        final parsed = tryJsonDecode(updatedValue);
        data = switch (parsed) {
          null => {},
          Map map => Map<String, dynamic>.from(map),
          _ => {'data': parsed},
        };
      } else {
        // Substitute variables in value.
        final updatedValue = PropertyValueDelegate.substituteVariables(
          subAction.newValue,
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
          scopedValues: scopedValues,
        );
        // Parse to JSON.
        final parsed = tryJsonDecode(updatedValue);
        data = switch (parsed) {
          null => {},
          Map map => Map<String, dynamic>.from(map),
          _ => {'data': parsed},
        };
      }

      return await cloudDatabase.addDocument(
        evaluatedPath,
        value: data,
        documentId: evaluatedDocumentId,
        autoGenerateId: subAction.autoGenerateId,
        skipCreationIfDocumentExists: subAction.skipCreationIfDocumentExists,
      );
    } catch (error, stackTrace) {
      _log(error.toString());
      _log(stackTrace.toString());
      return false;
    }
  }

  static Future<bool> updateDocumentOnCloud(
    UpdateDocumentSubAction subAction,
    ScopedValues scopedValues,
  ) async {
    final CloudDatabase? cloudDatabase = scopedValues.cloudDatabase;

    if (cloudDatabase == null) {
      _log('Cloud storage is null.');
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
      // Substitute variables in raw value.
      final updatedValue = PropertyValueDelegate.substituteVariables(
        subAction.rawValue,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );
      // Parse to JSON.
      final Map<String, dynamic> data = jsonDecode(updatedValue);

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
          subAction.path, evaluatedDocumentId);

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
        VariableType.text => newValue,
        VariableType.color => ColorRGBA.fromHex(newValue),
        VariableType.integer => _performIntOperation(subAction.numberOperation,
            currentValue?.toInt(), newValue, scopedValues),
        VariableType.decimal => _performDecimalOperation(
            subAction.numberOperation,
            currentValue?.toDouble(),
            newValue,
            scopedValues),
        VariableType.boolean => subAction.toggled
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

        _log(
            '[updateDocumentOnCloud 1] Setting storage key [$storageKey] to value [$value].');
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

      _log(
          '[updateDocumentOnCloud 2] Setting storage key [$storageKey] to value [$value].');
      docData[match.name] = storageData[match.name];

      return await cloudDatabase.updateDocument(
        evaluatedPath,
        documentId: evaluatedDocumentId,
        // Update only the field that was changed.
        value: {match.name: docData[match.name]},
      );
    } catch (error, stackTrace) {
      _log(error.toString());
      _log(stackTrace.toString());
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
        _log('Cloud storage is null.');
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
      _log(error.toString());
      _log(stackTrace.toString());
      return false;
    }
  }

  static Future<void> loadFromStorageAction(
    BuildContext context,
    LoadFromCloudStorageAction action,
  ) async {
    final ScopedValues scopedValues = ScopedValues.of(context);

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

    final CloudDatabase? cloudDatabase = scopedValues.cloudDatabase;

    if (cloudDatabase == null) {
      _log('Cloud storage is null. Waiting for it to initialize...');
      return;
    }

    if (action.loadSingleDocument) {
      final evaluatedDocumentId = PropertyValueDelegate.substituteVariables(
        action.documentId,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      );
      _log(
          'Streaming document from cloud storage: $evaluatedPath/$evaluatedDocumentId');
      cloudDatabase.streamDocumentToVariable(
          evaluatedPath, evaluatedDocumentId, variable);
    } else {
      _log('Streaming collection from cloud storage: $evaluatedPath');

      cloudDatabase.streamCollectionToVariable(
        evaluatedPath,
        variable,
        whereFilters: action.whereFilters,
        orderByOperations: action.orderByFilters,
        limit: (action.limit ?? 0) > 0 ? action.limit : null,
        scopedValues: ScopedValues.of(context),
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
      _log('Invalid value: $substitutedValue');
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
      _log('Invalid value: $substitutedValue');
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
