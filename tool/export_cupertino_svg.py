"""Export the pinned cupertino_icons font as immutable, monochrome SVGs.

Run with Python 3 and fonttools (`uv run --with fonttools python ...`):

    python tool/export_cupertino_svg.py --font /path/to/CupertinoIcons.ttf \
        --license /path/to/cupertino_icons/LICENSE --output /tmp/codelessly-icons

The output is <output>/cupertino/1.0.9/<lowercase hex codepoint>.svg.
Do not add the generated SVGs to the SDK package: deploy them to static hosting.
"""

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

FONT_VERSION = "1.0.9"
MAP_PATH = Path(__file__).resolve().parent.parent / "lib/src/utils/cupertino_icons_by_codepoint.dart"


def export(font_path: Path, license_path: Path, output_root: Path) -> int:
    source = MAP_PATH.read_text(encoding="utf-8")
    codepoints = sorted({int(value, 16) for value in re.findall(r"^  0x([0-9a-f]+):", source, re.M)})
    if not codepoints:
        raise ValueError(f"No Cupertino icon codepoints found in {MAP_PATH}")
    font = TTFont(font_path)
    cmap = font.getBestCmap()
    missing = set(codepoints) - cmap.keys()
    if missing:
        raise ValueError(f"Missing codepoints in font: {', '.join(hex(x) for x in sorted(missing))}")

    output = output_root / "cupertino" / FONT_VERSION
    output.mkdir(parents=True, exist_ok=True)
    glyphs = font.getGlyphSet()
    em = font["head"].unitsPerEm
    ascent = font["OS/2"].sTypoAscender
    for codepoint in codepoints:
        name = cmap[codepoint]
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(pen)
        path = pen.getCommands()
        if not path:
            raise ValueError(f"Empty glyph for {hex(codepoint)}")
        advance = font["hmtx"][name][0]
        x_offset = (em - advance) / 2
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 {em} {em}">\n'
            f'  <path transform="translate({x_offset:g} {ascent}) scale(1 -1)" '
            f'fill="#000" d="{path}"/>\n'
            '</svg>\n'
        )
        (output / f"{codepoint:x}.svg").write_text(svg, encoding="utf-8")
    shutil.copyfile(license_path, output / "LICENSE")
    (output / "manifest.json").write_text(
        json.dumps(
            {
                "family": "cupertino_icons",
                "version": FONT_VERSION,
                "font_sha256": hashlib.sha256(font_path.read_bytes()).hexdigest(),
                "glyph_count": len(codepoints),
                "codepoints": [f"{codepoint:x}" for codepoint in codepoints],
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    return len(codepoints)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--font", type=Path, required=True)
    parser.add_argument("--license", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    count = export(args.font, args.license, args.output)
    print(f"Exported {count} SVGs to {args.output / 'cupertino' / FONT_VERSION}")


if __name__ == "__main__":
    main()
