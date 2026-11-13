/// The Codelessly SDK: shows the screens a project publishes from the
/// Codelessly Editor as real Flutter UI, rendered natively (straight into
/// render objects) and running: variables, conditions, actions, navigation,
/// data, APIs and scripts.
///
/// A [Codelessly] is one published project; a [CodelesslyWidget] shows one
/// of its screens.
///
/// ```dart
/// import 'package:codelessly_sdk/codelessly_sdk.dart';
/// import 'package:flutter/material.dart';
///
/// void main() {
///   final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project'));
///   runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
/// }
/// ```
///
/// Where the publish comes from:
///
/// * a public slug, over HTTP: `Codelessly(config: CodelesslyConfig(slug: ...))`;
/// * a project token, from Firebase with live updates: `codelesslyWithToken`
///   in `package:codelessly_sdk/firebase.dart`;
/// * a bundle shipped with the app, offline: [Codelessly.asset] and
///   [Codelessly.fromBundle];
/// * anywhere else: a [PublishLoader] of the app's.
///
/// What an app gives its layouts: data ([CodelesslyWidget.data],
/// [Codelessly.setData]), route params ([CodelesslyWidget.params]), functions
/// ([CodelesslyConfig.functions]) and services ([CodelesslyConfig.services],
/// [Services]). A [CodelesslyWidgetController] reads and changes a shown
/// screen from outside.
///
/// This library also exports the model (`package:codelessly_api`) without
/// the value types that share Flutter's names (`Color`, `EdgeInsets`,
/// `TextStyle`...): import `package:codelessly_api/codelessly_api.dart`
/// with a prefix for those.
///
/// Other libraries: `firebase.dart` (Codelessly on Firebase) and
/// `store.dart` (in-app purchases).
library;

// The model, without the value types and enums that share Flutter's names
// (apps import both): use `import 'package:codelessly_api/codelessly_api.dart'
// as api;` for those.
export 'package:codelessly_api/codelessly_api.dart'
    hide
        Alignment,
        AutovalidateMode,
        Axis,
        BlendMode,
        BorderRadius,
        BorderSide,
        BorderStyle,
        BottomNavigationBarLandscapeLayout,
        BottomNavigationBarType,
        BoxConstraints,
        BoxFit,
        BoxHeightStyle,
        BoxWidthStyle,
        ButtonSegment,
        ButtonStyle,
        Clip,
        Color,
        ColorStop,
        CrossAxisAlignment,
        CustomPaint,
        Decoration,
        FieldValue,
        EdgeInsets,
        FloatingActionButtonLocation,
        FloatingLabelBehavior,
        FontStyle,
        IconAlignment,
        ImageRepeat,
        InputBorder,
        InputDecoration,
        ListTileControlAffinity,
        ListTileTitleAlignment,
        MainAxisAlignment,
        MainAxisSize,
        NavigationDestination,
        NavigationDestinationLabelBehavior,
        Offset,
        Paint,
        PaintingStyle,
        PathFillType,
        PointMode,
        ShapeBorder,
        ShowValueIndicator,
        SliderTrackShape,
        StrokeAlign,
        StrokeCap,
        StrokeJoin,
        TabAlignment,
        TabBarIndicatorSize,
        TextAlign,
        TextAlignVertical,
        TextCapitalization,
        TextDecoration,
        TextDecorationStyle,
        TextDirection,
        TextInputAction,
        TextInputType,
        TextLeadingDistribution,
        TextOverflow,
        TextStyle,
        TileMode,
        VerticalDirection,
        VisualDensity,
        WidgetState,
        WrapAlignment,
        WrapCrossAlignment;

// Hosts other than NodeView (an editor's board) show node boxes the same
// way: their element is an IslandOwnerElement and their render object mixes
// in IslandParent.
export 'src/render/islands.dart' show IslandEnvironment, IslandHost, IslandOwnerElement, IslandParent;
export 'src/render/contracts.dart';
export 'src/render/node_tree.dart' show RenderTree, NodeBox, NodeInteractions, ResponsiveWidth, NodeTreeObserver, Slot, SlotKind;
export 'src/widgets/tree.dart' show NodeTree, builtInCatalog;
export 'src/runtime/gestures/gestures.dart' show DragGestures;
export 'src/runtime/http_image_loader.dart';
// Text as the SDK renders it, for a host's own text (an in-place editor).
export 'src/render/convert.dart' show textStyle, FontDemand;
export 'src/render/paint/image_fill.dart' show imagesPendingUnder;
export 'src/text_defaults.dart' show kTextBase;
export 'src/render/node_view.dart';
export 'src/render/hero.dart' show HeroMarkPaint, HeroMarks, RenderHeroMark;
export 'src/render/play.dart' show FlightRegistry, RenderFlightBox;
export 'src/render/animations.dart' show AnimationClock, RenderAnimations;
export 'src/render/recipe.dart' show NodeChild, NodeBuilder, RecipeCatalog, WidgetRecipe;
export 'src/render/source.dart';
export 'src/widgets/media.dart' show ExternalComponents;
export 'src/services/services.dart';
// The script engine (Services.scripts' default) and what scripts can call.
export 'src/scripting/formula_scripts.dart';
export 'src/scripting/script_catalog.dart';
export 'src/scripting/script_runner.dart';
export 'src/scripting/sandbox/script_sandbox.dart';
export 'src/runtime/contracts.dart';
export 'src/runtime/expressions/expressions.dart';
export 'src/runtime/actions/actions.dart';
// The feature layers over the core runtime, and the runner that installs them.
export 'src/features/first_party.dart';
// Render objects that paint images, and whether one is still loading (tools wait for them before a capture).
export 'src/render/paint/image_fill.dart' show ImageClient, PaintImages;
export 'src/runtime/lists/lists.dart';
// What `${drag}` reads when nothing is dragged (a design canvas's default).
export 'src/runtime/gestures/drag_and_drop.dart' show dragIdleValues;
export 'src/runtime/expressions/perf_scope.dart' show PerfScope;
export 'src/widgets/collections_data_list.dart' show DataListView, DataListViewState, ListSection, SectionIndexBar, UndoBar, groupIntoSections, sectionOffset;
export 'src/widgets/collections_reorder.dart' show GroupReorderList, KeyboardReorderItem, ReorderListView;
export 'src/widgets/collections_swipe.dart' show SwipeActionsBox;

// The app shell: Codelessly, CodelesslyWidget, loading, navigation.
export 'src/app/app_identity.dart';
export 'src/app/automations.dart';
export 'src/app/back_guard.dart';
export 'src/app/backdrop_screens.dart';
export 'src/app/codelessly.dart';
export 'src/app/codelessly_widget.dart';
export 'src/app/config.dart';
export 'src/app/fonts.dart';
export 'src/app/loader.dart';
export 'src/app/managed_components.dart';
export 'src/app/hosted_plugins.dart';
export 'src/features/hosted/hosted.dart' show hostedPluginFeature;
export 'src/app/navigation.dart';
export 'src/app/overlay_screens.dart';
export 'src/app/page_transitions.dart';
export 'src/app/paywalls.dart';
export 'src/app/persisted_variables.dart';
export 'src/app/presenter.dart';
export 'src/app/runtime.dart';
export 'src/app/theme.dart' show themeDataOf, themeValues;
export 'src/app/viewport.dart';

export 'src/render/layout/design_scroll.dart' show RenderDesignScroll;
// What a WidgetRecipe's NodeBuilder.fitBox gives.
export 'src/render/layout/fit_box.dart' show RenderFitBox;
