// The Codelessly toolkit as an MCP server (stdio): headless rendering and the API reference as tools any agent
// can call, so the loop of writing a document and seeing it closes inside the conversation.
//
//   tool/codelessly mcp
//
// Register it with an MCP client, e.g. Claude Code (`.mcp.json`):
//
//   {"mcpServers": {"codelessly": {"command": "/path/to/CodelesslySDK/tool/codelessly", "args": ["mcp"]}}}
//
// Tools: codelessly_docs, codelessly_render (the report, the outline and the PNGs), codelessly_validate (notation expanded, writing nothing: issues and placeholder words as JSON),
// codelessly_flatten, codelessly_states. The first render or states call starts the render server
// (tool/render/serve.sh) when it is down, so later calls cost about a second; CODELESSLY_MCP_NO_SERVER=1 keeps every
// run separate. Inline documents are written under $CODELESSLY_MCP_WORK (default: a temp folder), one folder per
// call; every answer names its folder. Messages are newline-delimited JSON-RPC 2.0 (MCP stdio).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'common.dart';
import 'docs.dart';
import 'flatten.dart';
import 'outline.dart';

final Directory _work = () {
  final env = Platform.environment['CODELESSLY_MCP_WORK'];
  final d = env != null && env.isNotEmpty ? Directory(env) : Directory.systemTemp.createTempSync('codelessly-mcp-');
  return d..createSync(recursive: true);
}();
var _calls = 0;

Directory _callDir(String name) {
  _calls++;
  final t = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return Directory('${_work.path}/${two(t.hour)}${two(t.minute)}${two(t.second)}-${_calls.toString().padLeft(3, '0')}-$name')
    ..createSync(recursive: true);
}

Map<String, Object?> _text(String t) => {'type': 'text', 'text': t};
Map<String, Object?> _image(File f) => {'type': 'image', 'data': base64Encode(f.readAsBytesSync()), 'mimeType': 'image/png'};

const _stepSchema = {
  'type': 'object',
  'description': 'One interaction, run in order before the capture: {"tap": "id"}, {"type": "email=a@b.co"}, '
      '{"hover": "id"}, {"focus": "id"}, {"unfocus": true}, {"key": "Enter"}, {"set": "name=json"}, '
      '{"scroll": "id=px"}, {"drag": "id=dx,dy"}, {"double-tap": "id"}, {"long-press": "id"}, {"right-click": "id"}, {"reload": true}, {"wheel": "id=dy"}, {"pinch": "id=scale"}, {"navigate": "screen?param=value"}, {"wait": 500}. '
      '"id#n" picks the n-th copy a list repeats; "id@n" the n-th tab/segment.',
  'additionalProperties': true,
};
const _docProps = {
  'document': {
    'type': 'object',
    'description': 'A layout document (schema 3) inline. Nested children are lifted out (see codelessly_flatten), '
        'so a nested tree works too.',
  },
  'path': {
    'type': 'string',
    'description': 'A document file or a site folder (with site.json) on disk, instead of document. Image and font '
        'paths in it resolve from its folder.',
  },
};

final tools = <Map<String, Object?>>[
  {
    'name': 'codelessly_docs',
    'description': 'Look up the Codelessly API reference (the JSON document format: nodes, layout, decoration, '
        'state, actions, lists, navigation, forms...). No query: the pages and what each covers. A query: an anchor '
        '("forms-validation-and-an-error-state"), a declared name ("row", "navigate", "textField") or words ("sticky '
        'header", "dark mode") -> the best section, with other matches. Use starter=true once to get the base '
        'document every author reads first.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'starter': {'type': 'boolean', 'description': 'Return STARTER.md, the base (about 13k tokens).'},
        'full': {'type': 'boolean', 'description': 'Do not cut a long section.'},
      },
    },
  },
  {
    'name': 'codelessly_render',
    'description': 'Render a Codelessly document (or site) headless with the real SDK at each screen '
        'size, after optional interaction steps. Returns the problems found while rendering '
        "(overflow, clipped text, missing fonts, failed taps), an outline of every node's box and text, and the "
        'screenshots. Fix the problems, then render again.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        ..._docProps,
        'sizes': {'type': 'string', 'description': 'Comma-separated WxH, default "390x844,1440x900".'},
        'screen': {'type': 'string', 'description': 'Only this screen (canvas id, screen name, path).'},
        'steps': {'type': 'array', 'items': _stepSchema},
        'fullPage': {'type': 'boolean', 'description': 'Capture the whole scrolling page.'},
        'theme': {'type': 'string', 'enum': ['light', 'dark', 'system']},
        'compare': {'type': 'string', 'description': 'A reference PNG (or folder) to compare each capture with.'},
        'args': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'More render options, e.g. ["--fonts", "/path/fonts", "--now", "2026-01-01T09:00:00Z"].',
        },
        'images': {'type': 'boolean', 'description': 'Return the PNGs (default true).'},
        'outline': {'type': 'boolean', 'description': 'Return the outline (default true).'},
      },
    },
  },
  {
    'name': 'codelessly_flatten',
    'description': 'Turn a nested node tree ({"type": "column", "children": [{...}]}), trees per breakpoint '
        '({"trees": {"mobile": ..., "desktop": ...}}) or a document with nested children into a flat layout document. '
        '"key" names a node; "@key" strings elsewhere become its id.',
    'inputSchema': {
      'type': 'object',
      'required': ['tree'],
      'properties': {
        'tree': {'type': 'object'},
        'size': {'type': 'string', 'description': 'Canvas size for a non-canvas root, default 390x844.'},
        'screen': {'type': 'string'},
      },
    },
  },
  {
    'name': 'codelessly_validate',
    'description': 'Expand notation (a site folder with pages/ and components/, or one .txt) without writing anything, '
        'and return as JSON: "issues" (file, line, column, message), "placeholders" (each word that stood in for a '
        'word the notation, the design system and the site do not have: word, kind, signatures, where, nodes, '
        'resolution; with open=false a type refused), "words" (every other word beyond the core that did not resolve, '
        'or that the writer defined) and "skipped" (component files not loaded). A placeholder is a warning with '
        'open=true ("ok" stays true): define the word, or it is recorded for support.',
    'inputSchema': {
      'type': 'object',
      'required': ['path'],
      'properties': {
        'path': {'type': 'string', 'description': 'A site folder (pages/, components/, site/site.json) or a notation .txt file.'},
        'open': {'type': 'boolean', 'description': 'The open vocabulary (expand --open): unknown words stand in. Default true.'},
        'designSystem': {'type': 'string', 'description': 'A design system folder (design_system.json), optional.'},
        'dictionary': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Dictionaries: folders of definitions (a <Word>.txt each, a define), read in order after the '
              'page\'s, the site\'s and the design system\'s definitions. Default: those CODELESSLY_DICTIONARY lists.',
        },
      },
    },
  },
  {
    'name': 'codelessly_states',
    'description': 'Render every state listed in a states manifest (tool/codelessly states --help describes it), '
        'compare each with its reference, and return the summary (worst first) and a contact sheet.',
    'inputSchema': {
      'type': 'object',
      'required': ['manifest'],
      'properties': {
        'manifest': {'type': 'string', 'description': 'Path of the states.json manifest.'},
        'only': {'type': 'array', 'items': {'type': 'string'}},
      },
    },
  },
];

/// The toolkit run again with a command (its output would otherwise go into the MCP stream).
Future<(int, String)> _self(List<String> args, {Duration? timeout}) =>
    runCaptured('${sdkRoot.path}/tool/codelessly', args, timeout: timeout);

/// Starts the render server when it is not up (serve.sh answers at once when it is).
Future<void> _ensureServer() async {
  if ((Platform.environment['CODELESSLY_MCP_NO_SERVER'] ?? '').isNotEmpty) return;
  await runCaptured(serveScript, const [], timeout: const Duration(minutes: 15));
}

String _documentArg(Map args, Directory d) {
  if (args['path'] case final String p when p.isNotEmpty) {
    final path = absolute(p.startsWith('~/') ? '${Platform.environment['HOME']}${p.substring(1)}' : p);
    if (!FileSystemEntity.isFileSync(path) && !FileSystemEntity.isDirectorySync(path)) {
      throw UsageError('No such file or folder: $path');
    }
    return path;
  }
  if (args['document'] case final Map doc) {
    final f = File('${d.path}/document.json')..writeAsStringSync(prettyJson(flatten(doc)));
    return f.path;
  }
  throw const UsageError('Give "document" (inline JSON) or "path".');
}

Future<(List<Map<String, Object?>>, bool)> _call(String name, Map args) async {
  switch (name) {
    case 'codelessly_docs':
      if (args['starter'] == true) {
        final ref = findReference();
        return ([_text(File('${ref.path}/STARTER.md').readAsStringSync())], false);
      }
      final (code, text) = docsText([if (args['query'] case final String q when q.isNotEmpty) q, if (args['full'] == true) '--full']);
      return ([_text(text)], code != 0);
    case 'codelessly_render':
      await _ensureServer();
      final d = _callDir('render');
      final doc = _documentArg(args, d);
      final out = '${d.path}/out';
      final cmd = [
        doc, '--out', out, '--sizes', (args['sizes'] as String?) ?? '390x844,1440x900', '--dump-layout',
        if (args['screen'] case final String s) ...['--screen', s],
        if (args['fullPage'] == true) '--full-page',
        if (args['theme'] case final String t) ...['--theme', t],
        if (args['compare'] case final String c) ...['--compare', c],
        for (final x in (args['args'] as List?) ?? const []) '$x',
        ...[
          for (final s in ((args['steps'] as List?) ?? const []).cast<Map>())
            for (final e in s.entries) ...(e.value == true ? ['--${e.key}'] : ['--${e.key}', e.value is String ? e.value as String : jsonEncode(e.value)]),
        ],
      ];
      final (code, report) = await runCaptured(renderScript, cmd);
      final shown = report.split('\n').where((l) => !l.startsWith('Rendering with ')).join('\n').trim();
      final content = [_text('$shown\n\n(exit $code; files: $out)')];
      if (code != 2 && args['outline'] != false) {
        final text = outlineText(out, [doc]);
        if (text.trim().isNotEmpty) content.add(_text('Outline (type id, x,y wxh, text; ! warning, x error):\n$text'));
      }
      if (code != 2 && args['images'] != false && Directory(out).existsSync()) {
        final pngs = Directory(out).listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final png in pngs) {
          final n = png.uri.pathSegments.last;
          if ((n.endsWith('.diff.png') || n.endsWith('.compare.png')) && args['compare'] == null) continue;
          content
            ..add(_text(n))
            ..add(_image(png));
        }
      }
      return (content, code == 2);
    case 'codelessly_validate':
      final path = absolute('${args['path'] ?? ''}');
      if (!FileSystemEntity.isFileSync(path) && !FileSystemEntity.isDirectorySync(path)) throw UsageError('No such file or folder: $path');
      final script = '${sdkRoot.path}/tool/notation/notation.sh';
      final r = await Process.run(Platform.isWindows ? 'bash' : script, [
        if (Platform.isWindows) script,
        'validate', path,
        if (args['open'] != false) '--open',
        if (args['designSystem'] case final String ds when ds.isNotEmpty) ...['--design-system', absolute(ds)],
        for (final d in (args['dictionary'] as List?) ?? const []) ...['--dictionary', absolute('$d')],
      ]);
      final json = '${r.stdout}'.trim();
      return ([_text(json.isEmpty ? '${r.stderr}' : json)], json.isEmpty);
    case 'codelessly_flatten':
      final size = parseSize((args['size'] as String?) ?? '390x844');
      final doc = flatten(args['tree'], size: size, screen: args['screen'] as String?);
      final d = _callDir('flatten');
      final f = File('${d.path}/document.json')..writeAsStringSync(prettyJson(doc));
      return ([_text(prettyJson(doc)), _text('(written to ${f.path})')], false);
    case 'codelessly_states':
      await _ensureServer();
      final d = _callDir('states');
      final (_, out) = await _self([
        'states', '${args['manifest']}', '--out', d.path,
        for (final o in ((args['only'] as List?) ?? const [])) ...['--only', '$o'],
      ], timeout: const Duration(hours: 1));
      final content = [_text(out)];
      final summary = File('${d.path}/summary.md');
      if (summary.existsSync()) content.add(_text(summary.readAsStringSync()));
      final sheetFile = File('${d.path}/sheet.png');
      if (sheetFile.existsSync()) content.add(_image(sheetFile));
      return (content, false);
  }
  throw UsageError('Unknown tool: $name');
}

void _respond(Object? id, {Object? result, Object? error}) {
  stdout.writeln(jsonEncode({'jsonrpc': '2.0', 'id': id, if (error != null) 'error': error else 'result': result}));
}

Future<void> _handle(Map msg) async {
  final id = msg['id'];
  if (id == null) return; // a notification (notifications/initialized, cancelled...)
  final params = (msg['params'] as Map?) ?? const {};
  switch (msg['method']) {
    case 'initialize':
      _respond(id, result: {
        'protocolVersion': params['protocolVersion'] ?? '2025-06-18',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'codelessly', 'version': '2.0.0'},
        'instructions': 'Codelessly documents are JSON UIs rendered by the Codelessly SDK. Read the base first '
            '(codelessly_docs with starter=true), write a document, then codelessly_render it and fix what it reports '
            'until it is clean and looks right.',
      });
    case 'ping':
      _respond(id, result: {});
    case 'tools/list':
      _respond(id, result: {'tools': tools});
    case 'tools/call':
      final name = params['name'];
      if (!tools.any((t) => t['name'] == name)) {
        _respond(id, error: {'code': -32602, 'message': 'Unknown tool: $name'});
        return;
      }
      try {
        final (content, isError) = await _call('$name', (params['arguments'] as Map?) ?? const {});
        _respond(id, result: {'content': content, 'isError': isError});
      } catch (e, s) {
        // Reported to the model; the server keeps serving.
        _respond(id, result: {'content': [_text('${e.runtimeType}: $e\n${s.toString().split('\n').take(4).join('\n')}')], 'isError': true});
      }
    default:
      _respond(id, error: {'code': -32601, 'message': 'Method not found: ${msg['method']}'});
  }
}

Future<int> mcpMain(List<String> argv) async {
  if (argv.contains('-h') || argv.contains('--help')) {
    stdout.writeln('tool/codelessly mcp: the toolkit as an MCP server on stdio (codelessly_docs, '
        'codelessly_render, codelessly_validate, codelessly_flatten, codelessly_states).');
    return 0;
  }
  // One request at a time, in order, as the Python server answered them.
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    Object? msg;
    try {
      msg = jsonDecode(line);
    } catch (_) {
      _respond(null, error: {'code': -32700, 'message': 'Parse error'});
      continue;
    }
    if (msg is Map) await _handle(msg);
  }
  return 0;
}
