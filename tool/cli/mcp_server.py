#!/usr/bin/env python3
"""The Codelessly toolkit as an MCP server (stdio): headless rendering and the API reference as tools any agent
can call, so the loop of writing a document and seeing it closes inside the conversation.

    tool/codelessly mcp

Register it with an MCP client, e.g. Claude Code (`.mcp.json`):

    {"mcpServers": {"codelessly": {"command": "/path/to/CodelesslySDK/tool/codelessly", "args": ["mcp"]}}}

Tools:

* `codelessly_docs`      look up the API reference: a page list, a section by anchor or name, or a search.
* `codelessly_validate`  strict validation of a document (inline JSON or a path): codes, JSON pointers, fixes.
* `codelessly_render`    validate and render a document or site headless at each size, optionally after steps
                         (tap, type, navigate...): the report, the outline (boxes, texts, problems per node) and
                         the PNGs as images.
* `codelessly_flatten`   nested node trees (as the editor takes them) to a flat document.
* `codelessly_states`    every state of a site from a manifest: summary (worst first) and a contact sheet.

Inline documents are written under $CODELESSLY_MCP_WORK (default: a temp folder), one folder per call, so a call's
files can be read back; every answer names its folder. Messages are newline-delimited JSON-RPC 2.0 (MCP stdio).
"""
from __future__ import annotations

import base64
import io
import json
import os
import subprocess
import sys
import tempfile
import time
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
SDK = HERE.parents[1]
CODELESSLY = SDK / 'tool' / 'codelessly'
sys.path.insert(0, str(HERE))

import flatten as flatten_mod  # noqa: E402
import outline as outline_mod  # noqa: E402

WORK = Path(os.environ.get('CODELESSLY_MCP_WORK') or tempfile.mkdtemp(prefix='codelessly-mcp-'))
WORK.mkdir(parents=True, exist_ok=True)
_calls = 0

STEP_SCHEMA = {
    'type': 'object',
    'description': 'One interaction, run in order before the capture: {"tap": "id"}, {"type": "email=a@b.co"}, '
                   '{"hover": "id"}, {"focus": "id"}, {"unfocus": true}, {"key": "Enter"}, {"set": "name=json"}, '
                   '{"scroll": "id=px"}, {"drag": "id=dx,dy"}, {"navigate": "screen?param=value"}, {"wait": 500}. '
                   '"id#n" picks the n-th copy a list repeats; "id@n" the n-th tab/segment.',
    'additionalProperties': True,
}
DOC_PROPS = {
    'document': {'type': 'object', 'description': 'A layout document (schema 3) inline. Nested children are '
                 'lifted out (see codelessly_flatten), so a nested tree works too.'},
    'path': {'type': 'string', 'description': 'A document file or a site folder (with site.json) on disk, '
             'instead of document. Image and font paths in it resolve from its folder.'},
}

TOOLS = [
    {
        'name': 'codelessly_docs',
        'description': 'Look up the Codelessly API reference (the JSON document format: nodes, layout, decoration, '
                       'state, actions, lists, navigation, forms...). No query: the pages and what each covers. '
                       'A query: an anchor ("forms-validation-and-an-error-state"), a declared name ("row", '
                       '"navigate", "textField") or words ("sticky header", "dark mode") -> the best section, '
                       'with other matches. Use starter=true once to get the base document every author reads first.',
        'inputSchema': {'type': 'object', 'properties': {
            'query': {'type': 'string'},
            'starter': {'type': 'boolean', 'description': 'Return STARTER.md, the base (about 13k tokens).'},
            'full': {'type': 'boolean', 'description': 'Do not cut a long section.'},
        }},
    },
    {
        'name': 'codelessly_validate',
        'description': 'Validate a Codelessly document strictly, without rendering: every problem with a code, a '
                       'JSON pointer and a suggestion. Faster than codelessly_render when you only changed JSON.',
        'inputSchema': {'type': 'object', 'properties': dict(DOC_PROPS)},
    },
    {
        'name': 'codelessly_render',
        'description': 'Validate a Codelessly document (or site) and render it headless with the real SDK at each '
                       'screen size, after optional interaction steps. Returns the problems found (validation and '
                       'what only rendering shows: overflow, clipped text, missing fonts, failed taps), an outline '
                       'of every node\'s box and text, and the screenshots. Fix the problems, then render again.',
        'inputSchema': {'type': 'object', 'properties': {
            **DOC_PROPS,
            'sizes': {'type': 'string', 'description': 'Comma-separated WxH, default "390x844,1440x900".'},
            'screen': {'type': 'string', 'description': 'Only this screen (canvas id, screen name, path).'},
            'steps': {'type': 'array', 'items': STEP_SCHEMA},
            'fullPage': {'type': 'boolean', 'description': 'Capture the whole scrolling page.'},
            'theme': {'type': 'string', 'enum': ['light', 'dark', 'system']},
            'compare': {'type': 'string', 'description': 'A reference PNG (or folder) to compare each capture with.'},
            'args': {'type': 'array', 'items': {'type': 'string'},
                     'description': 'More render options, e.g. ["--fonts", "/path/fonts", "--now", "2026-01-01T09:00:00Z"].'},
            'images': {'type': 'boolean', 'description': 'Return the PNGs (default true).'},
            'outline': {'type': 'boolean', 'description': 'Return the outline (default true).'},
            'maxImageSide': {'type': 'integer', 'description': 'Scale images down to this longest side (default 1600).'},
        }},
    },
    {
        'name': 'codelessly_flatten',
        'description': 'Turn a nested node tree ({"type": "column", "children": [{...}]}), trees per breakpoint '
                       '({"trees": {"mobile": ..., "desktop": ...}}) or a document with nested children into a flat '
                       'layout document. "key" names a node; "@key" strings elsewhere become its id.',
        'inputSchema': {'type': 'object', 'required': ['tree'], 'properties': {
            'tree': {'type': 'object'},
            'size': {'type': 'string', 'description': 'Canvas size for a non-canvas root, default 390x844.'},
            'screen': {'type': 'string'},
        }},
    },
    {
        'name': 'codelessly_states',
        'description': 'Render every state listed in a states manifest (tool/cli/states.py describes it), compare '
                       'each with its reference, and return the summary (worst first) and a contact sheet.',
        'inputSchema': {'type': 'object', 'required': ['manifest'], 'properties': {
            'manifest': {'type': 'string', 'description': 'Path of the states.json manifest.'},
            'only': {'type': 'array', 'items': {'type': 'string'}},
        }},
    },
]


def call_dir(name: str) -> Path:
    global _calls
    _calls += 1
    d = WORK / f'{time.strftime("%H%M%S")}-{_calls:03d}-{name}'
    d.mkdir(parents=True, exist_ok=True)
    return d


def text(t: str) -> dict:
    return {'type': 'text', 'text': t}


def image(path: Path, max_side: int) -> dict:
    data = path.read_bytes()
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(data))
        if max(im.size) > max_side:
            scale = max_side / max(im.size)
            im = im.convert('RGB').resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
            buf = io.BytesIO()
            im.save(buf, 'PNG')
            data = buf.getvalue()
    except ImportError:
        pass
    return {'type': 'image', 'data': base64.b64encode(data).decode(), 'mimeType': 'image/png'}


def document_arg(args: dict, d: Path) -> str:
    if args.get('path'):
        p = Path(args['path']).expanduser()
        if not p.exists():
            raise ValueError(f'No such file or folder: {p}')
        return str(p.resolve())
    if 'document' in args and isinstance(args['document'], dict):
        doc = flatten_mod.flatten(args['document'])
        f = d / 'document.json'
        f.write_text(json.dumps(doc, indent=1, ensure_ascii=False))
        return str(f)
    raise ValueError('Give "document" (inline JSON) or "path".')


def run(cmd: list[str], timeout=900) -> tuple[int, str]:
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, (p.stdout + p.stderr).strip()


def step_args(steps) -> list[str]:
    out = []
    for s in steps or []:
        for k, v in s.items():
            out += [f'--{k}'] if v is True else [f'--{k}', v if isinstance(v, str) else json.dumps(v)]
    return out


def tool_docs(args):
    cmd = [str(CODELESSLY), 'docs']
    if args.get('starter'):
        code, path = run(cmd + ['--starter'])
        if code:
            return [text(path)], True
        return [text(Path(path).read_text())], False
    if args.get('query'):
        cmd.append(args['query'])
    if args.get('full'):
        cmd.append('--full')
    code, out = run(cmd)
    return [text(out)], code not in (0,)


def tool_validate(args):
    d = call_dir('validate')
    doc = document_arg(args, d)
    code, out = run([str(CODELESSLY), 'validate', doc, '--out', str(d / 'out')])
    return [text(f'{out}\n\n(files: {d})')], code == 2


def tool_render(args):
    d = call_dir('render')
    doc = document_arg(args, d)
    out = d / 'out'
    cmd = [str(CODELESSLY), 'render', doc, '--out', str(out), '--sizes', args.get('sizes') or '390x844,1440x900',
           '--dump-layout']
    if args.get('screen'):
        cmd += ['--screen', args['screen']]
    if args.get('fullPage'):
        cmd.append('--full-page')
    if args.get('theme'):
        cmd += ['--theme', args['theme']]
    if args.get('compare'):
        cmd += ['--compare', args['compare']]
    cmd += [str(a) for a in args.get('args') or []]
    cmd += step_args(args.get('steps'))
    code, report = run(cmd)
    report = '\n'.join(l for l in report.splitlines() if not l.startswith('Rendering with '))
    content = [text(f'{report}\n\n(exit {code}; files: {out})')]
    if code != 2 and args.get('outline', True):
        types, parents = outline_mod.load_documents([doc])
        lines = []
        for lf in sorted(out.glob('*.layout.json')):
            cap = lf.name.replace('.png.layout.json', '').replace('.layout.json', '')
            lines.append(f'== {cap}')
            lines += outline_mod.outline_capture(json.loads(lf.read_text()), types, parents,
                                                 outline_mod.capture_diagnostics(out, cap))
            lines.append('')
        if lines:
            content.append(text('Outline (type id, x,y wxh, text; ! warning, x error):\n' + '\n'.join(lines)))
    if code != 2 and args.get('images', True):
        for png in sorted(out.glob('*.png')):
            if png.name.endswith(('.diff.png', '.compare.png')) and not args.get('compare'):
                continue
            content.append(text(png.name))
            content.append(image(png, int(args.get('maxImageSide') or 1600)))
    return content, code == 2


def tool_flatten(args):
    size = tuple(int(x) for x in (args.get('size') or '390x844').lower().split('x'))
    doc = flatten_mod.flatten(args['tree'], size=size, screen=args.get('screen'))
    d = call_dir('flatten')
    (d / 'document.json').write_text(json.dumps(doc, indent=1, ensure_ascii=False))
    return [text(json.dumps(doc, indent=1, ensure_ascii=False)), text(f'(written to {d / "document.json"})')], False


def tool_states(args):
    d = call_dir('states')
    cmd = [str(CODELESSLY), 'states', args['manifest'], '--out', str(d)]
    for o in args.get('only') or []:
        cmd += ['--only', o]
    code, out = run(cmd, timeout=3600)
    content = [text(out)]
    if (d / 'summary.md').exists():
        content.append(text((d / 'summary.md').read_text()))
    if (d / 'sheet.png').exists():
        content.append(image(d / 'sheet.png', 2400))
    return content, False


HANDLERS = {'codelessly_docs': tool_docs, 'codelessly_validate': tool_validate, 'codelessly_render': tool_render,
            'codelessly_flatten': tool_flatten, 'codelessly_states': tool_states}


def respond(msg_id, result=None, error=None):
    m = {'jsonrpc': '2.0', 'id': msg_id}
    if error is not None:
        m['error'] = error
    else:
        m['result'] = result
    sys.stdout.write(json.dumps(m) + '\n')
    sys.stdout.flush()


def handle(msg: dict):
    method = msg.get('method')
    mid = msg.get('id')
    if mid is None:
        return  # a notification (notifications/initialized, cancelled...)
    if method == 'initialize':
        version = (msg.get('params') or {}).get('protocolVersion') or '2025-06-18'
        respond(mid, {'protocolVersion': version, 'capabilities': {'tools': {}},
                      'serverInfo': {'name': 'codelessly', 'version': '1.0.0'},
                      'instructions': 'Codelessly documents are JSON UIs rendered by the Codelessly SDK. Read the '
                                      'base first (codelessly_docs with starter=true), write a document, then '
                                      'codelessly_render it and fix what it reports until it is clean and looks right.'})
    elif method == 'ping':
        respond(mid, {})
    elif method == 'tools/list':
        respond(mid, {'tools': TOOLS})
    elif method == 'tools/call':
        params = msg.get('params') or {}
        name = params.get('name')
        if name not in HANDLERS:
            respond(mid, error={'code': -32602, 'message': f'Unknown tool: {name}'})
            return
        try:
            content, is_error = HANDLERS[name](params.get('arguments') or {})
        except Exception as e:  # report to the model, keep serving
            content, is_error = [text(f'{type(e).__name__}: {e}\n{traceback.format_exc(limit=3)}')], True
        respond(mid, {'content': content, 'isError': is_error})
    else:
        respond(mid, error={'code': -32601, 'message': f'Method not found: {method}'})


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ('-h', '--help'):
        print(__doc__)
        return 0
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            respond(None, error={'code': -32700, 'message': 'Parse error'})
            continue
        handle(msg)
    return 0


if __name__ == '__main__':
    sys.exit(main())
