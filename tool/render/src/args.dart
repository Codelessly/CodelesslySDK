// The render command's arguments.
import 'dart:ui' show Size;

/// One interaction, applied in order before the capture.
final class Step {
  const Step(this.kind, this.target, [this.value]);

  /// tap, hover, set, scroll, navigate or wait.
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
  --full-page             Capture the whole scrollable height, not the viewport.
  --fonts <dir>           Font files (.ttf/.otf, read by their real family and
                          weight). Repeatable. Roboto and Material Icons are built in.
  --tap <nodeId>          Tap the node (where it shows on screen). <nodeId>#<n>
                          picks the n-th copy (0-based) of a node a list repeats.
  --hover <nodeId>        Move a mouse over the node.
  --set <name>=<json>     Set a variable of the screen (value as JSON: 1, true, "a").
  --scroll <nodeId|screen>=<px>   Scroll a scrolling node (or the page) to px.
  --navigate <screen>     Push a screen (canvas id, layout id or URL path).
  --wait <ms>             Let time pass (animations, delays, toasts).
  --label <text>          Append -<text> to the PNG names (state screenshots).
  --validate-only         Only validate; render nothing.
  --dump-layout           Also write <png>.layout.json: every node's box (x, y, w, h).
Steps (--tap, --hover, --set, --scroll, --navigate, --wait) run in the order given.
''';

/// Parses [argv]; throws a [FormatException] with a message for bad input.
RenderArgs parseArgs(List<String> argv) {
  final inputs = <String>[];
  String? out;
  var sizes = RenderArgs.defaultSizes;
  final screens = <String>[];
  final steps = <Step>[];
  final fonts = <String>[];
  var fullPage = false, validateOnly = false, dumpLayout = false;
  String? label;
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
      case '--tap' || '--hover' || '--navigate' || '--wait':
        steps.add(Step(a.substring(2), next(i++, a)));
      case '--set' || '--scroll':
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
  );
}
