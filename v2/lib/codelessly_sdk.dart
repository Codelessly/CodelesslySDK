/// Codelessly SDK: renders Codelessly layouts natively.
library;

// The model, without the value types and enums that share Flutter's names
// (apps import both): use `import 'package:codelessly_api_v2/codelessly_api.dart'
// as api;` for those.
export 'package:codelessly_api_v2/codelessly_api.dart'
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
export 'src/render/node_tree.dart' show NodeTree, NodeBox, NodeTreeObserver, Slot, SlotKind;
// Text as the SDK renders it, for a host's own text (an in-place editor).
export 'src/render/convert.dart' show textStyle;
export 'src/text_defaults.dart' show kTextBase;
export 'src/render/node_view.dart';
export 'src/render/recipe.dart' show NodeChild;
export 'src/render/source.dart';
export 'src/widgets/media.dart' show ExternalComponents;
export 'src/services/services.dart';
export 'src/runtime/contracts.dart';
export 'src/runtime/expressions/expressions.dart';
export 'src/runtime/actions/actions.dart';

// The app shell: Codelessly, CodelesslyWidget, loading, navigation.
export 'src/app/codelessly.dart';
export 'src/app/codelessly_widget.dart';
export 'src/app/config.dart';
export 'src/app/fonts.dart';
export 'src/app/loader.dart';
export 'src/app/navigation.dart';
export 'src/app/runtime.dart';
export 'src/app/theme.dart' show themeDataOf;
export 'src/app/viewport.dart';
