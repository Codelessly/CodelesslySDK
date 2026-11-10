"""Writes lib/src/utils/directional_icons.dart: the base names of Flutter's
Material icons declared with matchTextDirection: true, which mirror in a
right-to-left layout.

    python3 tool/generate_directional_icons.py [path/to/flutter]
"""
import re
import sys

flutter = sys.argv[1] if len(sys.argv) > 1 else '/opt/flutter'
src = open(f'{flutter}/packages/flutter/lib/src/material/icons.dart').read()
names = set()
for m in re.finditer(r'static const IconData (\w+) = IconData\(([^;]*?)\);', src, re.S):
    if 'matchTextDirection: true' in m.group(2):
        name = m.group(1)
        for suffix in ('_outlined', '_rounded', '_sharp'):
            if name.endswith(suffix):
                name = name[:-len(suffix)]
        names.add(name)
lines = ["// Generated from Flutter's Icons (matchTextDirection: true); see",
         '// tool/generate_directional_icons.py. Do not edit by hand.', '',
         '/// Names of the Material icons that point a reading direction (arrows,',
         '/// chevrons, undo, send, ...): Flutter mirrors them in a right-to-left',
         '/// layout, and so does an icon drawn from its SVG.',
         'const Set<String> directionalMaterialIcons = {']
lines += [f"  '{n}'," for n in sorted(names)] + ['};', '']
open('lib/src/utils/directional_icons.dart', 'w').write('\n'.join(lines))
