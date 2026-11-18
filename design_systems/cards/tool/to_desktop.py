"""The examples of TO-DESKTOP.md, expanded and rendered.

    python3 design_systems/cards/tool/to_desktop.py [--no-render]

Each ```notation cards=<name>``` block of TO-DESKTOP.md becomes a page of a Cards site and each
```notation desk=<name>``` block a page of a Desk site, under examples/to-desktop/patterns/{cards,desk}. The Cards
site is expanded at 390 (a phone's page) and rendered at 390x844; the Desk site is expanded at 1440 and rendered at
1440x900 and 390x844. The pictures go to examples/to-desktop/patterns/out/<cards|desk>-<name>@<size>.png.
"""
import json
import os
import re
import shutil
import subprocess
import sys

CARDS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SDK = os.path.dirname(os.path.dirname(CARDS))
OUT = os.path.join(CARDS, 'examples', 'to-desktop', 'patterns')


def blocks():
    text = open(os.path.join(CARDS, 'TO-DESKTOP.md'), encoding='utf-8').read().replace('\r\n', '\n')
    for m in re.finditer(r'```notation (cards|desk)=([a-z]+)\n(.*?)```', text, re.S):
        yield m.group(1), m.group(2), m.group(3)


def main():
    sites = {'cards': [], 'desk': []}
    for ds, name, body in blocks():
        pages = os.path.join(OUT, ds, 'pages')
        os.makedirs(pages, exist_ok=True)
        open(os.path.join(pages, name + '.txt'), 'w', encoding='utf-8', newline='\n').write(body)
        sites[ds].append(name)
    for ds, names in sites.items():
        site = os.path.join(OUT, ds, 'site')
        os.makedirs(site, exist_ok=True)
        system = '../../../../..' if ds == 'cards' else '../../../../../../desk'
        manifest = {'schema': 3, 'pages': [n + '.json' for n in names], 'designSystem': system}
        open(os.path.join(site, 'site.json'), 'w', encoding='utf-8', newline='\n').write(json.dumps(manifest, indent=1) + '\n')
    if '--no-render' in sys.argv:
        return
    shots = os.path.join(OUT, 'out')
    for ds, width, sizes in (('cards', '390', '390x844'), ('desk', '1440', '1440x900,390x844')):
        folder = os.path.join(OUT, ds)
        subprocess.run(['bash', 'tool/notation/notation.sh', 'expand', folder, '--width', width, '--no-record'], cwd=SDK, check=True)
        tmp = os.path.join(OUT, 'out-' + ds)
        subprocess.run(['bash', 'tool/codelessly', 'render', os.path.join(folder, 'site'), '--out', tmp, '--sizes', sizes, '--full-page'], cwd=SDK)
        os.makedirs(shots, exist_ok=True)
        for f in os.listdir(tmp):
            if f.endswith('.png'):
                shutil.copy(os.path.join(tmp, f), os.path.join(shots, ds + '-' + f))
            elif f.startswith('diagnostics'):
                shutil.copy(os.path.join(tmp, f), os.path.join(shots, ds + '-' + f))
        shutil.rmtree(tmp)


main()
