// The render command's arguments.
import 'dart:ui' show Size;

/// One interaction, applied in order before the capture.
final class Step {
  const Step(this.kind, this.target, [this.value]);

  /// tap, hover, focus, unfocus, key, type, set, scroll, navigate or wait.
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
    this.validateOnly = false,
    this.dumpLayout = false,
    this.component,
    this.componentsAll = false,
    this.props,
    this.slots,
    this.compare,
    this.theme,
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
  final bool validateOnly;

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
        validateOnly: validateOnly,
        dumpLayout: dumpLayout,
        component: component,
        componentsAll: componentsAll,
        props: props,
        slots: slots,
        compare: compare,
        theme: theme,
      );
}

const usage = '''
Usage: tool/render/render.sh <document.json | directory> [...] --out <dir> [options]

Validates Codelessly layout documents strictly, renders every screen with the
SDK at each size, and reports what is wrong. Writes <out>/<screen>@<w>x<h>.png
and <out>/diagnostics.json. Exits 1 when there are errors, 0 otherwise.

Options:
  --out <dir>             Where PNGs and diagnostics.json go (required).
  --sizes <WxH,...>       Screen sizes (default 390x844,834x1112,1440x900).
  --screen <id|name>      Only this screen: a canvas id, a layout id, a screen
                          name (props.screen), a canvas name or path. Repeatable.
  --full-page             Capture the whole page from its top (whatever the steps
                          scrolled it to), not the window where they left it.
  --fonts <dir|system>    Font files (.ttf, .otf, .woff; read by their real family,
                          weight and style), searched recursively: a font package
                          folder (node_modules/@fontsource/<family>), a site's fonts.
                          `system`: the system's font directories. Repeatable.
                          Roboto and Material Icons are built in.
  --theme <mode>          Start in this theme mode: light, dark or system (the
                          device's: light), as a setThemeMode action sets it;
                          named colors, text styles and controls follow. PNGs
                          get -<mode> in their names. Steps may toggle it.
  --tap <nodeId>          Tap the node (where it shows on screen). <nodeId>#<n>
                          picks the n-th copy (0-based) of a node a list repeats.
  --hover <nodeId>        Move a mouse over the node.
  --focus <nodeId>        Focus a text field (or the field inside the node).
  --type <nodeId>=<text>  Focus a text field and type text into it, as a user
                          would (its changed reactions run; a field bound to a
                          variable through props.initialValue sets it).
  --set <name>=<json>     Set a variable of the screen (value as JSON: 1, true, "a").
  --scroll <nodeId|screen>=<px>   Scroll a scrolling node (or the page) to px.
  --navigate <screen>     Push a screen (canvas id, layout id or URL path).
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
  --label <text>          Append -<text> to the PNG names (state screenshots);
                          diagnostics go to diagnostics-<text>.json.
  --validate-only         Only validate; render nothing.
  --dump-layout           Also write <png>.layout.json: every node's box (x, y, w, h).
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
Steps (--tap, --hover, --focus, --unfocus, --key, --type, --set, --scroll, --navigate, --wait) run in the order given.
''';

/// Parses [argv]; throws a [FormatException] with a message for bad input.
RenderArgs parseArgs(List<String> argv) {
  final inputs = <String>[];
  String? out;
  var sizes = RenderArgs.defaultSizes;
  final screens = <String>[];
  final steps = <Step>[];
  final fonts = <String>[];
  var fullPage = false, validateOnly = false, dumpLayout = false, componentsAll = false;
  String? label, component, props, slots, compare, theme;
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
      case '--validate-only':
        validateOnly = true;
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
      case '--unfocus':
        steps.add(const Step('unfocus', ''));
      case '--tap' || '--hover' || '--focus' || '--navigate' || '--wait' || '--key':
        steps.add(Step(a.substring(2), next(i++, a)));
      case '--set' || '--scroll' || '--type':
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
    validateOnly: validateOnly,
    dumpLayout: dumpLayout,
    component: component,
    componentsAll: componentsAll,
    props: props,
    slots: slots,
    compare: compare,
    theme: theme,
  );
}
