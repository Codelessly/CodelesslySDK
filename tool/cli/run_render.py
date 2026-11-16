#!/usr/bin/env python3
"""`tool/codelessly render` and `tool/codelessly validate`: the render command (tool/render/render.sh) with two
conveniences for agents.

    tool/codelessly render <documents> --out <dir> [render options] [--outline] [--sheet]
    tool/codelessly validate <documents> [--out <dir>]

--outline also dumps the layout and prints every capture's outline (tool/codelessly outline): each node's box and
text with its problems, the text an agent reads before the PNGs. --sheet writes <out>/sheet.png, every capture of
the run on one image. validate is render --validate-only with a scratch --out when none is given. Every other
option is the render command's (tool/render/README.md); the exit status is its.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SDK = HERE.parents[1]
RENDER = SDK / 'tool' / 'render' / 'render.sh'
sys.path.insert(0, str(HERE))

# Render options that take a value (so their value is not a document).
VALUED = {'--out', '--sizes', '--screen', '--fonts', '--theme', '--tap', '--double-tap', '--wheel', '--pinch', '--drag', '--hover', '--focus', '--key',
          '--type', '--set', '--now', '--scroll', '--navigate', '--wait', '--label', '--compare', '--compare-map',
          '--design-system', '--component', '--props', '--slots'}


def split(args: list[str]):
    docs, out = [], None
    i = 0
    while i < len(args):
        a = args[i]
        if a in VALUED:
            if a == '--out' and i + 1 < len(args):
                out = args[i + 1]
            i += 2
            continue
        if not a.startswith('--'):
            docs.append(a)
        i += 1
    return docs, out


def main(argv: list[str]) -> int:
    mode = argv[0] if argv and argv[0] in ('render', 'validate') else 'render'
    args = argv[1:] if argv and argv[0] in ('render', 'validate') else list(argv)
    if not args or args[0] in ('-h', '--help'):
        print(__doc__)
        if mode == 'render':
            print((SDK / 'tool' / 'render' / 'README.md').read_text().split('## What it reports')[0])
        return 0 if args else 2
    outline = '--outline' in args
    sheet = '--sheet' in args
    args = [a for a in args if a not in ('--outline', '--sheet')]
    docs, out = split(args)
    scratch = None
    if mode == 'validate':
        if '--validate-only' not in args:
            args.append('--validate-only')
        if out is None:
            scratch = tempfile.mkdtemp(prefix='codelessly-validate-')
            args += ['--out', scratch]
    elif out is None:
        print('--out <dir> is required (where the PNGs and diagnostics.json go).', file=sys.stderr)
        return 2
    if outline and '--dump-layout' not in args:
        args.append('--dump-layout')
    code = subprocess.run([str(RENDER), *args]).returncode
    if scratch:
        shutil.rmtree(scratch, ignore_errors=True)
    if code != 2 and out and (outline or sheet):
        sys.stdout.flush()
        if outline:
            import outline as ol
            print()
            ol.main([out, *docs])
        if sheet:
            import sheet as sh
            made = sh.make_sheet([out], os.path.join(out, 'sheet.png'))
            if made:
                print(f'wrote {made}')
    return code


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
