# codelessly_genui

> Built on the legacy Codelessly SDK and API, 10.x (the code at this repository's root), not on SDK 20.x
> ([`v2/`](../../v2)).

Renders [A2UI](https://a2ui.org) v0.9.1 surfaces, the declarative UI that AI agents send, with the Codelessly SDK. It also includes the component catalog an LLM is prompted with.

- **Protocol**: built on the official `a2ui_core` 0.5 (messages, data model, bindings, validation) and `a2ui_flutter` 0.1 (per-component reactive views).
- **Rendering**: each component is drawn by a Codelessly node through the SDK's own transformers: text, buttons, sliders, checkboxes, text fields, segmented pickers, charts, gauges, progress bars and switches.
- **Incremental updates**: an `updateDataModel` or `updateComponents` message rebuilds only the components it touches.
- **Events**: user interactions come back as typed `GenUiEvent`s (`GenUiActionEvent`, `GenUiValueChanged`, `GenUiErrorEvent`), each with the surface's data model. `toA2uiMessage()` gives the A2UI message to send to the agent.
- **Live formulas**: `calc` runs a pure Codelessly formula over the data model on the device, so charts and totals recompute as the user drags.
- **Expandable visualizations**: `CodelesslyVisualization` expands inline content to fullscreen with a hero transition and collapses it back, keeping its state.

## Use

```dart
final session = GenUiSession();
session.events.listen((event) {
  if (event is GenUiActionEvent) sendToAgent(event.toA2uiMessage());
});

// Streamed render_ui tool input: each message applies as soon as it is complete.
final feed = session.openStream(depth: 2);
for (final chunk in toolInputChunks) feed.add(chunk);

// In build:
ValueListenableBuilder(
  valueListenable: session.surfaces,
  builder: (context, surfaces, _) => Column(children: [
    for (final s in surfaces) GenUiSurfaceView(surface: s),
  ]),
);
```

- **Prompt the agent** with `genUiSystemPrompt()` and the `render_ui` tool (`renderToolInputSchema()`).
- **Catalog document**: `catalog/codelessly_genui_catalog.json`, id `https://codelessly.com/a2ui/catalogs/genui/v1/catalog.json`. Regenerate it with `dart run tool/generate_catalog.dart`; a test fails when it is stale.

The design (mapping both ways, data model, security, versioning) is in `CodelesslyEditor/docs/genui_a2ui.md`.
