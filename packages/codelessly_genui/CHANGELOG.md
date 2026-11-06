## Unreleased

- A Slider sends its commit action once, 600 ms after its value stops changing (`kSliderCommitDelay`). Before, each keyboard step sent its own event to the agent.

- First version: A2UI v0.9.1 renderer on a2ui_core 0.5 and a2ui_flutter 0.1, with the Codelessly GenUI catalog (basic components plus Codelessly* charts, gauges, metrics, tables and expandable visualizations), the `calc` formula function, two-way A2UI↔Codelessly node mapping, streamed message parsing and typed user-action events.
