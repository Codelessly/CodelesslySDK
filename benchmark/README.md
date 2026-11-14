# Benchmarks

Release-mode web benchmarks of the SDK runtime. There are two apps:

- `lib/main.dart` runs a publish bundle as an app and times its frames and
  script runs (see the header of that file).
- `lib/compare.dart` shows the same screen twice and times it: once as a
  document rendered by `codelessly_sdk`, once written by hand with Flutter's
  Material widgets. The rest of this page is about this one.

## What `compare.dart` measures

The screen is `groups` sections in one scrolling column. Each section has a
title, a switch, a slider, a text field and a button. A line at the top shows
a counter. Nothing is built lazily on either side: the whole column sits in a
`SingleChildScrollView`.

- SDK side: the screen is written in the compact notation, parsed into a
  `LayoutDocument`, and shown by `CodelesslyView` in a `UiSession`. The counter
  is bound to `data.tick`.
- Flutter side: a `Column` of `Text`, `Switch`, `Slider`, `TextField` and
  `FilledButton`. Only the counter's `Text` is rebuilt when the counter
  changes.

One page load runs one side, in three phases. Both sides run the same phases
with the same frame counts.

| Number | Meaning |
| --- | --- |
| `notationToDocumentMs` | SDK only. Parsing the notation and creating the `UiSession`, before `runApp`. |
| `runAppToFirstFrameMs` | From the `runApp` call to the end of the first frame on the UI thread: widget inflation, layout, paint, scene building. Rasterization is not included. |
| `firstFrameBuildMs` | The first frame alone (begin-frame to post-frame callbacks): layout, paint, scene building. It is part of `runAppToFirstFrameMs`. |
| `updateBuildMs` | 120 frames in which only the counter changes. UI-thread time per frame. |
| `scrollBuildMs` | 240 frames that jump the scroll position from the top to the bottom in equal steps. UI-thread time per frame. |
| `scrollExtent` | The scrollable height in logical pixels (content height minus the 900 px viewport). |

Frame times are taken with a stopwatch from the frame's begin-frame callbacks
to its post-frame callbacks. The result also carries the engine's own
`FrameTiming` build durations for the same frames
(`engineUpdateBuildMs`, `engineScrollBuildMs`); in the runs below they agree
with the stopwatch medians to within 2 ms. The raster durations
(`updateRasterMs`, `scrollRasterMs`) are reported too but are not meaningful
here, see the caveats.

## How to run it

```sh
cd benchmark
flutter build web --release --no-web-resources-cdn -t lib/compare.dart
python3 -m http.server 5217 --directory build/web &

# One run of one side. Prints "[bench-result] {json}".
node tool/run_web.mjs http://localhost:5217/ "side=sdk&groups=20"
node tool/run_web.mjs http://localhost:5217/ "side=flutter&groups=20"

# Several runs per side, alternating sides, with medians across runs.
python3 tool/compare_runs.py http://localhost:5217/ 20 7
python3 tool/compare_runs.py http://localhost:5217/ 150 7
```

`tool/run_web.mjs` needs a globally installed Playwright with Chromium. Set
`BENCH_TIMEOUT` (milliseconds) to change its timeout; the default is 90000.
`--no-web-resources-cdn` bundles CanvasKit so the page loads without network
access. `flutter test test/compare_test.dart` is a smoke test that both sides
lay out and show the counter.

## Results, 2026-11-14

Seven page loads per side at each size, sides alternated. Each cell is the
median across the seven runs, with the lowest and highest run in parentheses.
All times are milliseconds on the UI thread. For `updateBuildMs` and
`scrollBuildMs`, "median" and "p90" are per-frame statistics within a run, and
the cell is the median of that statistic across runs.

### groups=20

| Number | SDK | Flutter | Faster |
| --- | --- | --- | --- |
| `notationToDocumentMs` | 33.6 (27.3–40.2) | n/a | n/a |
| `runAppToFirstFrameMs` | 284.7 (246.4–318.7) | 372.7 (256.5–390.5) | SDK, but the ranges overlap |
| `notationToDocumentMs` + `runAppToFirstFrameMs` (sum of medians) | 318.3 | 372.7 | SDK, but the ranges overlap |
| `firstFrameBuildMs` | 227.7 (193.0–244.5) | 162.8 (109.1–171.2) | Flutter |
| `updateBuildMs` median | 7.3 (6.5–8.3) | 7.4 (6.5–8.7) | No difference |
| `updateBuildMs` p90 | 13.3 (12.4–14.3) | 13.4 (12.1–15.4) | No difference |
| `scrollBuildMs` median | 4.0 (3.4–4.5) | 5.6 (4.5–6.0) | SDK |
| `scrollBuildMs` p90 | 5.9 (5.6–7.5) | 8.6 (7.1–11.4) | SDK |
| `scrollExtent` (px) | 2928 | 3940 | The SDK screen is 21% shorter |

### groups=150

| Number | SDK | Flutter | Faster |
| --- | --- | --- | --- |
| `notationToDocumentMs` | 93.0 (83.4–113.1) | n/a | n/a |
| `runAppToFirstFrameMs` | 782.3 (729.5–829.9) | 972.5 (838.4–1196.1) | SDK |
| `notationToDocumentMs` + `runAppToFirstFrameMs` (sum of medians) | 875.3 | 972.5 | SDK, by less than the run-to-run spread on the Flutter side |
| `firstFrameBuildMs` | 720.7 (662.2–772.2) | 460.1 (353.8–531.6) | Flutter |
| `updateBuildMs` median | 22.1 (19.2–29.9) | 35.0 (31.5–37.4) | SDK |
| `updateBuildMs` p90 | 34.4 (30.7–42.5) | 48.3 (42.7–53.4) | SDK |
| `scrollBuildMs` median | 16.5 (14.8–18.0) | 29.0 (26.5–31.7) | SDK |
| `scrollBuildMs` p90 | 25.9 (21.9–27.5) | 40.9 (39.7–42.2) | SDK |
| `scrollExtent` (px) | 27498 | 35140 | The SDK screen is 22% shorter |

### Reading the numbers

- The SDK is slower on `firstFrameBuildMs` at both sizes (by about 40% at 20
  groups and 57% at 150). It does more of its work inside the first frame and
  less during widget inflation; the Flutter side is the other way around. The
  comparable figure for "time until the screen is laid out and painted" is
  `runAppToFirstFrameMs`, and for the SDK the document also has to be made
  first, so the sum row is the fairest start-up comparison. On that row the
  SDK is ahead at both sizes, but at 20 groups the two sides' ranges overlap
  almost entirely, so treat that row as "no clear difference".
- At 20 groups the update phase shows no difference between the sides.
- At 150 groups the SDK's frames are shorter in both the update and scroll
  phases, and the per-run ranges do not overlap. Neither side fits a 16.7 ms
  frame at the median in this setup.
- A frame in which one line of text changes costs 7 ms at 20 groups and 22 to
  35 ms at 150 on both sides, and it grows with the number of sections. So
  this phase mostly measures something that scales with the whole column, not
  the cost of delivering one changed value. We did not profile what that is.

## Caveats

- **The two screens are not the same size.** The SDK's controls are more
  compact, so its column is about 21–22% shorter (see `scrollExtent`). The
  number of widgets is the same, but the two sides do not draw the same
  pixels, and the scroll phase covers less distance per frame on the SDK
  side.
- **The controls are different implementations.** The Flutter side uses
  Material's `Switch`, `Slider`, `TextField` and `FilledButton`. The SDK draws
  its own controls. The benchmark compares the two as a user would get them,
  not the same widgets through two paths, and we have not measured how much
  of the difference comes from the controls themselves.
- **Headless Chromium with software rendering.** The runs used Playwright's
  headless Chromium 153 with ANGLE on SwiftShader, on a 4-core Intel Xeon
  2.1 GHz virtual machine with no GPU. Raster times from this setup say
  nothing about a real device, so they are left out of the tables. The
  UI-thread times above are the meaningful ones, and even those are specific
  to this machine: expect different absolute numbers elsewhere.
- **Web release build only.** Flutter 3.50.0, Dart 3.14.0, compiled to
  JavaScript with the CanvasKit renderer. Native (AOT) builds and WebAssembly
  builds were not measured and may rank differently.
- **One screen.** A long, non-lazy form with one bound value. It says nothing
  about lists built lazily, images, animations, scripts, or screens with many
  bound values.
- **Run-to-run noise is large.** First-frame numbers varied by up to about 50%
  between runs of the same side, and single runs of the update phase at 20
  groups went either way. Compare medians over several runs, not single runs.
- The first-frame numbers include one-time costs of a fresh page (first
  execution of the code paths involved), which both sides pay.
