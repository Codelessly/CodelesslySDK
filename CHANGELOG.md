## 9.2.0

Requires codelessly_api 9.1.0.

### Features

- Formula functions for curves: `spline(points)` (SVG path data of a smooth
  curve through `{x, y}` points), `pathPoints(path, n)` (n points equally
  spaced by arc length, with their direction), `pathPoint(path, t)` and
  `pathLength(path)`. A motion path can be built from variables and
  measured along.
- `motion.keyframes` bindings; under keyframes that push a node off its path,
  `orientToPath` turns it with its real movement.
- Path nodes take bound stroke and fill colours, `trimMs` / `trimCurve` (a
  trim that keeps pace with a flight) and a bound `dashPattern`; a
  rectangle's `path` is bindable.
- Drag tracks take their geometry and range from `dragTrack.<field>`
  bindings (`x2: ${= parent.width - 28}`), and follow a bound `drag.enabled`.
- `screen.breakpoint` / `isMobile` inside a responsive layout follow its own
  switch widths.
- Toasts can be tilted and come in on any curve.

### Fixes

- Computed variables whose formulas read `storage`, `route`, `screen` or
  `auth` (directly or through other computed variables) are cached again,
  keyed by those values: such chains were worked out again on every read,
  which could freeze an app for seconds.
- A draggable node moved by bound `x`/`y` is grabbed where it is drawn.
- Children of a frame with `contentFit` are placed in its design size, so a
  child aligned in a 960 x 600 design drawn in a phone keeps its place.
- `parent` in a fixed-size child of a frame reads the frame's content box,
  not the child's own size.
- A frozen loop (`motion.loop` bound off) keeps the values its formulas give.
- An image paint without a URL draws nothing instead of throwing.

