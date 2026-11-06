/// Renders A2UI (agent-to-UI) surfaces with the Codelessly SDK.
///
/// - [GenUiSession] applies A2UI messages (streamed or whole) and reports
///   user interactions as typed [GenUiEvent]s.
/// - [GenUiSurfaceView] renders a surface.
/// - [genUiCatalog] is the Codelessly GenUI catalog; [buildGenUiCatalogJson]
///   is its published document and [genUiSystemPrompt] the agent prompt.
library;

export 'package:a2ui_core/a2ui_core.dart'
    show
        SurfaceModel,
        A2uiRendererAction,
        A2uiRendererError,
        A2uiProtocolVersion;
export 'package:a2ui_flutter/a2ui_flutter.dart'
    show ComponentImplementation, A2uiSurface;

export 'src/catalog/catalog_spec.dart';
export 'src/catalog/genui_catalog.dart';
export 'src/functions/calc_function.dart'
    show
        CalcFunction,
        evaluateCalc,
        formulaPathToPointer,
        pointerToFormulaPath,
        calcExpressionError;
export 'src/mapping/a2ui_codelessly_mapping.dart';
export 'src/mapping/node_mapping.dart';
export 'src/prompt/system_prompt.dart';
export 'src/render/codelessly_node_view.dart';
export 'src/render/components.dart' show kSliderCommitDelay, CommitOnUserChange;
export 'src/render/genui_surface_view.dart';
export 'src/render/genui_theme.dart';
export 'src/render/visualization.dart' show GenUiDisplayMode;
export 'src/session/events.dart';
export 'src/session/genui_session.dart';
export 'src/session/stream_parser.dart';
