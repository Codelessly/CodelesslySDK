// Small published projects for the presenter and automation tests.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

export 'support.dart' show settle;

/// A layout [id] with one canvas ([width] × [height]) that is all one box:
/// a click anywhere on it runs [onClick]; its load runs [onLoad].
PublishLayout screen(
  String id, {
  double width = 300,
  double height = 200,
  List<Json> onClick = const [],
  List<Json> onLoad = const [],
  List<Variable> variables = const [],
  Map<String, Object?> extraNodes = const {},
  List<String> children = const [],
}) =>
    PublishLayout.fromJson({
      'schema': 2,
      'id': id,
      'roots': ['$id-canvas'],
      'variables': {
        '$id-canvas': [for (final v in variables) v.toJson()],
      },
      'nodes': {
        '$id-canvas': {
          'type': 'canvas',
          'name': id,
          'slots': {'body': '$id-body'},
          'layout': {'width': width, 'height': height},
          if (onLoad.isNotEmpty)
            'actions': [
              {'trigger': {'type': 'load'}, 'actions': onLoad},
            ],
        },
        '$id-body': {
          'type': 'stack',
          'layout': {'width': {'fill': width}, 'height': {'fill': height}},
          'decoration': {
            'fills': [
              {'color': '#FF3366CC'},
            ],
          },
          'children': children,
          if (onClick.isNotEmpty)
            'actions': [
              {'trigger': {'type': 'click'}, 'actions': onClick},
            ],
        },
        ...extraNodes,
      },
    });

/// A project of [layouts] (the first is the entry screen) and [automations].
PublishBundle bundleOf(List<PublishLayout> layouts, {List<Automation> automations = const []}) => PublishBundle(
      model: PublishModel(
        projectId: 'sandbox',
        entryLayoutId: layouts.first.id,
        layouts: {for (final l in layouts) l.id: PublishLayoutInfo.of(l)},
      ).withAutomations(automations),
      layouts: {for (final l in layouts) l.id: l},
    );

/// The host app: [home] (an empty screen), with the presenter's overlay as
/// `MaterialApp.builder`.
Widget overlayApp(Codelessly codelessly, {Widget? home, bool automations = true}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => CodelesslyOverlay(codelessly: codelessly, automations: automations, child: child!),
      home: home ?? const Scaffold(body: SizedBox.expand()),
    );

/// A 400 × 800 phone at 1 pixel per point.
void setSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);
}
