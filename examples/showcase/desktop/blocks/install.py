#!/usr/bin/env python3
"""Installs designed desktop blocks into design_systems/cards/components (the build keeps them).

    python3 examples/showcase/desktop/blocks/install.py <dir of design_block.py outputs> [names...]

Takes each block's kept round (summary.json's "final") when it passed; skips a name the system already has
from SSUI. Run design_systems/cards/tool/build.py --no-showcase after it.
"""
import json, os, shutil, sys
SDK = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
src = os.path.abspath(sys.argv[1]); only = sys.argv[2:]
comp = f'{SDK}/design_systems/cards/components'
ssui = {f[:-5] for f in os.listdir(f'{SDK}/design_systems/ssui/components')} if os.path.isdir(f'{SDK}/design_systems/ssui/components') else set()
for name in sorted(os.listdir(src)):
    s = f'{src}/{name}/summary.json'
    if not os.path.isfile(s) or (only and name not in only):
        continue
    d = json.load(open(s))
    f = f'{src}/{name}/round{d.get("final")}/{name}.json'
    if d.get('status') != 'passed' or not os.path.exists(f):
        print(f'{name}: not installed ({d.get("status")})'); continue
    if name in ssui:
        print(f'{name}: not installed (SSUI has one of that name)'); continue
    shutil.copy(f, f'{comp}/{name}.json')
    pic = f'{src}/{name}/round{d.get("final")}/light.png'
    out = f'{SDK}/examples/showcase/desktop/blocks/pictures'
    os.makedirs(out, exist_ok=True)
    if os.path.exists(pic):
        from PIL import Image
        im = Image.open(pic).convert('RGB'); im = im.crop((0, 0, im.width, min(im.height, 1000))); im.resize((im.width // 2, im.height // 2)).save(f'{out}/{name}.png')
    print(f'{name}: installed (round {d.get("final")})')
