// The render command's arguments.
import 'dart:ui' show Size;

/// One interaction, applied in order before the capture.
final class Step {
  const Step(this.kind, this.target, [this.value]);

  /// tap, double-tap, long-press, right-click, hover, focus, unfocus, key,
  /// type, set, scroll, drag, wheel, pinch, navigate, reload or wait.
  final String kind;
  final String target;
  final String? value;

  @override
  String toString() => '--$kind $target${value == null ? '' : '=$value'}';
}

final class RenderArgs {
  RenderArgs({
    required this.inputs,
    required this.out,
    this.sizes = defaultSizes,
    this.screens = const [],
    this.fullPage = false,
    this.steps = const [],
    this.fontDirs = const [],
    this.label,
    this.dumpLayout = false,
    this.component,
    this.componentsAll = false,
    this.props,
    this.slots,
    this.compare,
    this.theme,
    this.compareMap = const {},
    this.now,
    this.imageMap = const {},
  });

  static const defaultSizes = [Size(390, 844), Size(834, 1112), Size(1440, 900)];

  final List<String> inputs;
  final String out;
  final List<Size> sizes;
  final List<String> screens;
  final bool fullPage;
  final List<Step> steps;
  final List<String> fontDirs;
  final String? label;

  /// Also write each capture's node boxes (`<png name>.layout.json`).
  final bool dumpLayout;

  /// Render this component alone (its type), not the site's pages.
  final String? component;

  /// Render every component of the site alone, each once per preview (at
  /// its size; without previews, with its defaults at each size), not the
  /// site's pages.
  final bool componentsAll;

  /// The parameters to render [component] with (a JSON object); null: each
  /// of its previews, else its defaults.
  final String? props;

  /// A fixture file with what [component]'s call passes to its slots.
  final String? slots;

  /// A reference screenshot (or a directory of them) each capture is
  /// compared with: a side-by-side and a diff image, and the bands where
  /// they differ.
  final String? compare;

  /// `--theme`: the theme mode the site starts in (`light`, `dark` or
  /// `system`), as a `setThemeMode` action would set it; steps may change
  /// it. Null: the site's own (`theme.mode`, else the device's: light).
  final String? theme;
  /// `--compare-map`: the reference name a capture's screen (or
  /// `<screen>-<label>`) is compared under (`home=index`).
  final Map<String, String> compareMap;

  /// `--now`: the instant `now()` returns (an ISO 8601 time), so clocks and
  /// countdowns written from it are the same in every capture.
  final DateTime? now;

  /// `--image-map`: network image URLs starting with a prefix read from a folder instead (`https://cdn.x/art/` →
  /// `assets/art`), so images a document names by URL show in the capture.
  final Map<String, String> imageMap;

  /// These arguments with other [sizes] and [screens].
  RenderArgs copyWith({List<Size>? sizes, List<String>? screens}) => RenderArgs(
        inputs: inputs,
        out: out,
        sizes: sizes ?? this.sizes,
        screens: screens ?? this.screens,
        fullPage: fullPage,
        steps: steps,
        fontDirs: fontDirs,
        label: label,
        dumpLayout: dumpLayout,
        component: component,
        componentsAll: componentsAll,
        props: props,
        slots: slots,
        compare: compare,
        theme: theme,
        compareMap: compareMap,
        now: now,
        imageMap: imageMap,
      );
}

const usage = '''
Usage: tool/render/render.sh <document.json | directory> [...] --out <dir> [options]

Renders every screen of Codelessly layout documents with the SDK at each
size, and reports what went wrong. Writes <out>/<screen>@<w>x<h>.png and
<out>/diagnostics.json. Exits 1 when there are errors, 0 otherwise.

Options:
  --out <dir>             Where PNGs and diagnostics.json go (required).
  --sizes <WxH,...>       Screen sizes (default 390x844,834x1112,1440x900).
  --screen <id|name>      Only this screen: a canvas id, a layout id, a screen
                          name (props.screen), a canvas name or path. Repeatable.
  --full-page             Capture the whole page from its top (whatever the steps
                          scrolled it to), not the window where they left it.
                          A dialog, drawer or menu open over it is captured at the
                          window's size; lists that load more as their end comes
                          into view load no more while the page is captured.
  --fonts <dir|system>    Font files (.ttf, .otf, .woff; read by their real family,
                          weight and style), searched recursively: a font package
                          folder (node_modules/@fontsource/<family>), a site's fonts.
                          `system`: the system's font directories. Repeatable.
                          Roboto, Roboto Mono (monospace) and Material Icons are
                          built in; symbols they lack (arrows) fall back to the
                          system's symbol font.
  --theme <mode>          Start in this theme mode: light, dark or system (the
                          device's: light), as a setThemeMode action sets it;
                          named colors, text styles and controls follow. PNGs
                          get -<mode> in their names. Steps may toggle it.
  --tap <nodeId>          Tap the node (where it shows on screen). <nodeId>#<n>
                          picks the n-th copy (0-based) of a node a list repeats.
                          shift+<nodeId> (ctrl+, alt+, meta+, mod+) holds keys
                          through it: a Shift-click. Also on --drag, --hover,
                          --double-tap, --long-press, --right-click.
  --hover <nodeId>        Move a mouse over the node.
  --focus <nodeId>        Put the keyboard focus on the node: a text field (or the
                          field inside it), else the control or press target in
                          it (a button, a row with a tap reaction, a handle).
  --type <nodeId>=<text>  Focus a text field and type text into it, as a user
                          would (its changed reactions run; a field bound to a
                          variable through props.initialValue sets it).
  --set <name>=<json>     Set a variable of the screen in view (value as JSON: 1,
                          true, "a"). It holds: a timer or load reaction that
                          writes it later does not change the capture.
  --now <ISO time>        The time now() returns (2026-11-13T09:00:00Z): clocks
                          and countdowns are the same in every run.
  --scroll <nodeId|screen>=<px>   Scroll a scrolling node (or the page) to px.
  --navigate <screen>     Push a screen: a canvas id, a screen name or a URL path,
                          with a query string for its params (speaker?id=ada,
                          /project?id=7): the screen reads them as \${route.id}.
  --drag <nodeId>=<dx>,<dy>   Press on the node, move by dx, dy in a fifth of a
                          second and release (a reorder handle, a slider, a
                          draggable card, a swipe: --drag row=-140,0).
  --drag <nodeId>=<nodeId>    Drag the node onto another node (a drop target).
  --double-tap <nodeId>   Tap the node twice in quick succession (a double tap, a
                          double click: a photo's zoom).
  --long-press <nodeId>   Hold a finger on the node, then lift (a longPress
                          reaction, a context menu on touch).
  --right-click <nodeId>  Click the node with a mouse's secondary button (a
                          secondaryClick reaction, a context menu).
  --reload                Close the app and start it again on the same screen
                          with what it kept on the device: a variable marked
                          saved keeps its value, every other starts over.
  --wheel <nodeId>=<dy>   Turn a mouse wheel over the node by dy pixels (negative:
                          away from the user); =ctrl+<dy> with Control held.
  --pinch <nodeId>=<scale>    Two fingers on the node, spread to <scale> times as far
                          apart (2 zooms in, 0.5 out).
  --wait <ms>             Let time pass (animations, delays, toasts).
  --unfocus               Take the focus from the focused field (no caret in the
                          capture; its blur/unfocus reactions run).
  --key <key>             Press a key on what has the focus: ArrowLeft, ArrowRight,
                          ArrowUp, ArrowDown, Enter, Escape, Tab, Space, Home, End,
                          Backspace, PageUp, PageDown, a letter or digit; with
                          modifiers: shift+Tab, ctrl+a.
  --compare <png|dir>     Compare each capture with a reference screenshot (a
                          file, or a directory holding <screen>...<w>x<h>...png):
                          writes <png>.compare.png (side by side) and
                          <png>.diff.png, and prints the bands where they differ.
                          A file in the directory matches when its name is the
                          screen, the state (the --label, else default or none)
                          and the size, exactly: home--saved--390x844.png.
  --compare-map <a>=<b>   Compare screen a (or a-<label>) under the reference
                          name b: home=index. Repeatable.
  --image-map <url>=<dir> Read network images whose URL starts with <url> from
                          <dir> (the rest of the URL as the path), so they show:
                          https://cdn.example.com/art/=assets/art. Repeatable.
  --label <text>          Append -<text> to the PNG names (state screenshots);
                          diagnostics go to diagnostics-<text>.json (with the
                          --screen and non-default --sizes before the label:
                          diagnostics-home@1440x900-<text>.json).
  --state <label> <steps> One run, several states: each --state starts a state
                          named <label> (as --label) with the steps after it,
                          from a fresh start; what comes before the first
                          --state is every state's. One Flutter start for all.
  --dump-layout           Also write <png>.layout.json: every node's box (x, y, w, h) and the text it shows.
  --component <Type>      Render one component of the site alone: once per preview
                          (at its size), or with --props at each size.
  --components-all        Render every component of the site alone, each once per
                          preview (at its size; without one, at each size with its
                          defaults): <Type>-<preview>@<w>x<h>.png.
  --props '<json>'        The component's parameters, as a call's "props".
  --slots <file>          What the call passes to the component's slots:
                          {"children": [ids], "slots": {name: id}, "nodes": {...}}.
A directory with site.json (or a components/ directory) is a site: its pages
and its components (one file each, the file named after the component type),
the fonts site.json declares ("fonts", files beside it: no --fonts needed) and
the images its documents name by a path relative to the site (images/a.jpg).
Steps name nodes inside components by path: --tap plans/card1/cta (the call
ids from the page down, then the node's id; <segment>#<n> picks a list copy).
Steps (--tap, --double-tap, --long-press, --right-click, --hover, --focus, --unfocus, --key, --type, --set, --scroll, --drag, --wheel, --pinch, --navigate, --reload, --wait) run in the order given.
''';

/// Parses [argv]; throws a [FormatException] with a message for bad input.
RenderArgs parseArgs(List<String> argv) {
  final inputs = <String>[];
  String? out;
  var sizes = RenderArgs.defaultSizes;
  final screens = <String>[];
  final steps = <Step>[];
  final fonts = <String>[];
  var fullPage = false, dumpLayout = false, componentsAll = false;
  String? label, component, props, slots, compare, theme;
  DateTime? now;
  final compareMap = <String, String>{};
  final imageMap = <String, String>{};
  String next(int i, String flag) {
    if (i + 1 >= argv.length) throw FormatException('$flag needs a value.');
    return argv[i + 1];
  }

  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    switch (a) {
      case '--out':
        out = next(i++, a);
      case '--sizes':
        sizes = [
          for (final s in next(i++, a).split(','))
            if (RegExp(r'^\s*(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)\s*$').firstMatch(s) case final m?)
              Size(double.parse(m[1]!), double.parse(m[2]!))
            else
              throw FormatException('Bad size "$s": write WIDTHxHEIGHT, e.g. 390x844.'),
        ];
      case '--screen':
        screens.add(next(i++, a));
      case '--full-page':
        fullPage = true;
      case '--dump-layout':
        dumpLayout = true;
      case '--fonts':
        fonts.add(next(i++, a));
      case '--label':
        label = next(i++, a);
      case '--component':
        component = next(i++, a);
      case '--components-all':
        componentsAll = true;
      case '--props':
        props = next(i++, a);
      case '--slots':
        slots = next(i++, a);
      case '--compare':
        compare = next(i++, a);
      case '--theme':
        theme = next(i++, a).trim().toLowerCase();
        if (!const ['light', 'dark', 'system'].contains(theme)) {
          throw FormatException('--theme takes light, dark or system (Flutter\'s ThemeMode), got "$theme".');
        }
      case '--compare-map':
        final v = next(i++, a);
        final eq = v.indexOf('=');
        if (eq <= 0 || eq == v.length - 1) throw FormatException('--compare-map takes <screen>=<reference name>, got "$v".');
        compareMap[v.substring(0, eq).trim()] = v.substring(eq + 1).trim();
      case '--image-map':
        final v = next(i++, a);
        // The prefix is a URL (it has its own "="s rarely): the folder is after the last "=".
        final eq = v.lastIndexOf('=');
        if (eq <= 0 || eq == v.length - 1) throw FormatException('--image-map takes <url prefix>=<folder>, got "$v".');
        imageMap[v.substring(0, eq).trim()] = v.substring(eq + 1).trim();
      case '--now':
        final v = next(i++, a);
        now = DateTime.tryParse(v);
        if (now == null) throw FormatException('--now takes an ISO 8601 time (2026-11-13T09:00:00Z), got "$v".');
      case '--unfocus':
        steps.add(const Step('unfocus', ''));
      case '--reload':
        steps.add(const Step('reload', ''));
      case '--tap' || '--double-tap' || '--long-press' || '--right-click' || '--hover' || '--focus' || '--navigate' || '--wait' || '--key':
        steps.add(Step(a.substring(2), next(i++, a)));
      case '--set' || '--scroll' || '--type' || '--drag' || '--wheel' || '--pinch':
        final v = next(i++, a);
        final eq = v.indexOf('=');
        if (eq < 0) throw FormatException('$a takes <target>=<value>, got "$v".');
        steps.add(Step(a.substring(2), v.substring(0, eq), v.substring(eq + 1)));
      case '-h' || '--help':
        throw const FormatException(usage);
      default:
        if (a.startsWith('--')) throw FormatException('Unknown option $a.\n\n$usage');
        inputs.add(a);
    }
  }
  if (inputs.isEmpty) throw FormatException('Name a document or a directory of documents.\n\n$usage');
  if (out == null) throw FormatException('--out <dir> is required.\n\n$usage');
  return RenderArgs(
    inputs: inputs,
    out: out,
    sizes: sizes,
    screens: screens,
    fullPage: fullPage,
    steps: steps,
    fontDirs: fonts,
    label: label,
    dumpLayout: dumpLayout,
    component: component,
    componentsAll: componentsAll,
    props: props,
    slots: slots,
    compare: compare,
    theme: theme,
    compareMap: compareMap,
    now: now,
    imageMap: imageMap,
  );
}

/// The runs [argv] asks for: itself, or with `--state <label>` one run per
/// state (what comes before the first `--state` is every state's, then
/// `--label <label>` and the state's own arguments).
List<List<String>> stateRuns(List<String> argv) {
  final first = argv.indexOf('--state');
  if (first < 0) return [argv];
  final common = argv.sublist(0, first);
  if (common.contains('--label')) throw const FormatException('--label and --state do not go together: each state is labelled by its name.');
  final runs = <List<String>>[];
  final labels = <String>{};
  for (var i = first; i < argv.length;) {
    if (i + 1 >= argv.length || argv[i + 1].startsWith('--')) throw const FormatException('--state needs a name: --state <label> <steps>.');
    final label = argv[i + 1];
    if (!labels.add(label)) throw FormatException('Two states are named "$label": each needs its own name.');
    var end = i + 2;
    while (end < argv.length && argv[end] != '--state') {
      end++;
    }
    runs.add([...common, '--label', label, ...argv.sublist(i + 2, end)]);
    i = end;
  }
  return runs;
}
