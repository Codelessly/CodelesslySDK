import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../codelessly_sdk.dart';
import '../error/error_handler.dart';

enum ApiRequestType {
  get,
  post,
  put,
  patch,
  delete;

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
  // TODO: URL should be environment specific.
  static const String _firebaseCloudFunctionsBaseURL =
      'https://us-central1-codeless-dev.cloudfunctions.net';

  static void performAction(BuildContext context, ActionModel action,
      {dynamic internalValue}) async {
    switch (action.type) {
      case ActionType.navigation:
        navigate(context, action as NavigationAction);
        break;
      case ActionType.link:
        launchURL((action as LinkAction).url);
        break;
      case ActionType.submit:
        submitToNewsletter(context, action as SubmitAction);
        break;
      case ActionType.setValue:
        setValue(
          context,
          action as SetValueAction,
          internalValue: internalValue,
        );
        break;
      case ActionType.setVariant:
        setVariant(context, action as SetVariantAction);
        break;
      case ActionType.callFunction:
        callFunction(context, action as CallFunctionAction);
        break;
    }
  }

  static void navigate(BuildContext context, NavigationAction action) {
    if (action.navigationType == NavigationType.pop) {
      Navigator.pop(context);
    } else {
      final Codelessly codelessly = context.read<Codelessly>();
      // Check if a layout exists for the action's [destinationId].
      final String? layoutId = codelessly
          .publishDataManager.publishModel!.layouts.values
          .firstWhereOrNull((layout) => layout.canvasId == action.destinationId)
          ?.id;

      if (layoutId == null) {
        CodelesslyErrorHandler.instance.captureException(
          CodelesslyException.layoutNotFound(
              message: 'Layout with id [$layoutId] does not exist.'),
        );
        return;
      }

      if (action.navigationType == NavigationType.push) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CodelesslyWidget(
              codelessly: codelessly,
              layoutID: layoutId,
            ),
          ),
        );
      } else if (action.navigationType == NavigationType.replace) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CodelesslyWidget(
              codelessly: codelessly,
              layoutID: layoutId,
            ),
          ),
        );
      }
    }
  }

  static void launchURL(String url) => launchUrl(Uri.parse(url));

  /// Makes API request using cloud function to prevent any CORS issues.
  static Future<http.Response> makeApiRequest({
    required ApiRequestType requestType,
    required String url,
    required Map<String, dynamic> headers,
    required Map<String, dynamic> body,
  }) async {
    return http.post(
      Uri.parse('$_firebaseCloudFunctionsBaseURL/makeApiRequest'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'url': url,
        'method': requestType.prettify,
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
            ?.value ??
        '';
    // Do nothing if field is empty.
    if (emailID.isEmpty) return;
    // Submit to selected newsletter service.
    switch (action.service) {
      case SubmitActionService.mailchimp:
        submitToMailchimp(context, action as MailchimpSubmitAction, emailID);
        break;
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
            ?.value ??
        '';
    final String lastName = lastNameFieldValues
            .firstWhereOrNull((value) => value.name == 'inputValue')
            ?.value ??
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
    final Map<String, dynamic> headers = {
      'Authorization': 'auth ${action.apiKey}'
    };
    // Submit data to Mailchimp.
    return makeApiRequest(
      requestType: ApiRequestType.post,
      url: url,
      headers: headers,
      body: body,
    );
  }

  static void setValue(
    BuildContext context,
    SetValueAction action, {
    dynamic internalValue,
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
        toggle: value is BoolValue
            ? () {
                return currentValue.copyWith(
                  value:
                      currentValue.value == null ? null : !currentValue.value!,
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
        break;
      case SetValueMode.toggle:
        // Get new toggle value.
        if (toggle != null) newValue = toggle();
        break;
      case SetValueMode.syncValue:
        // Get new synced value.
        if (syncValue != null) newValue = syncValue();
        break;
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
      codelesslyContext.nodeValues[action.nodeID]!.value = updateValues;
    }
  }

  static void setVariant(BuildContext context, SetVariantAction action) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get node's values.
    final List<ValueModel> values = payload.nodeValues[action.nodeID]!.value;
    // Get new variant value.
    final ValueModel newValue =
        StringValue(name: 'variant', value: action.variantID);
    // Get old value by name.
    final ValueModel oldValue =
        values.firstWhere((value) => value.name == newValue.name);
    // Replace old value with new.
    final List<ValueModel> updateValues = [...values]
      ..remove(oldValue)
      ..add(newValue);
    // Update values list.
    payload.nodeValues[action.nodeID]!.value = updateValues;
  }

  static void callFunction(BuildContext context, CallFunctionAction action) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    final CodelesslyFunction? function =
        codelesslyContext.functions[action.name];
    function?.call(codelesslyContext);
  }
}
