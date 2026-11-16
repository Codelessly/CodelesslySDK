#!/usr/bin/env python3
"""Many screenshots as one labelled contact sheet: one image to look at instead of twenty.

    tool/codelessly sheet <png | dir>... --out sheet.png [--height 480] [--columns n] [--title text]

Each image is scaled to --height (aspect kept) under its file name; a directory adds its PNGs (not `*.diff.png`,
`*.compare.png`, nor earlier sheets). Without --columns, images of one state (the part of the name before `@`)
share a row, so a render's phone, tablet and desktop captures sit side by side. A model reads one sheet far
cheaper than the separate captures, and sees the sizes against each other.

Uses Pillow when it is installed, else ImageMagick's `montage`.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def collect(paths: list[str]) -> list[Path]:
    out: list[Path] = []
    for p in paths:
        path = Path(p)
        if path.is_dir():
            out += [f for f in sorted(path.rglob('*.png'))
                    if not f.name.endswith(('.diff.png', '.compare.png')) and not f.name.startswith('sheet')
                    and not any(part.startswith('.') for part in f.relative_to(path).parts)]
        elif path.exists():
            out.append(path)
    return out


def rows_of(images: list[Path], columns: int | None) -> list[list[Path]]:
    if columns:
        return [images[i:i + columns] for i in range(0, len(images), columns)]
    rows: dict[str, list[Path]] = {}
    for f in images:
        stem = f.name[:-4]
        screen, _, size = stem.partition('@')
        state = size.split('-', 1)[1] if '-' in size else ''
        rows.setdefault(f'{f.parent}/{screen}|{state}', []).append(f)
    return [sorted(r, key=width_of) for r in rows.values()]


def width_of(f: Path) -> int:
    """`home@390x844-saved.png` -> 390: a row runs from the narrowest size to the widest."""
    size = f.name.partition('@')[2]
    try:
        return int(size.split('x')[0])
    except ValueError:
        return 0


def label_of(f: Path, base: Path | None) -> str:
    try:
        return str(f.relative_to(base)) if base else f.name
    except ValueError:
        return f.name


def with_pillow(rows, out: Path, height: int, title: str | None, base: Path | None) -> bool:
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return False
    try:
        font = ImageFont.load_default(size=14)
    except TypeError:
        font = ImageFont.load_default()
    pad, label_h = 12, 22
    title_h = 34 if title else 0
    scaled_rows = []
    for row in rows:
        cells = []
        for f in row:
            im = Image.open(f).convert('RGB')
            w = max(1, round(im.width * height / im.height)) if im.height > height else im.width
            h = min(height, im.height)
            cells.append((f, im.resize((w, h), Image.LANCZOS) if (w, h) != im.size else im))
        scaled_rows.append(cells)
    width = max(sum(im.width for _, im in cells) + pad * (len(cells) + 1) for cells in scaled_rows)
    total_h = title_h + sum(max(im.height for _, im in cells) + label_h + pad for cells in scaled_rows) + pad
    sheet = Image.new('RGB', (width, total_h), (236, 238, 241))
    draw = ImageDraw.Draw(sheet)
    if title:
        draw.text((pad, 9), title, fill=(17, 24, 39), font=font)
    y = title_h + pad
    for cells in scaled_rows:
        x = pad
        for f, im in cells:
            draw.text((x, y + 3), label_of(f, base), fill=(55, 65, 81), font=font)
            sheet.paste(im, (x, y + label_h))
            draw.rectangle([x - 1, y + label_h - 1, x + im.width, y + label_h + im.height], outline=(203, 208, 215))
            x += im.width + pad
        y += max(im.height for _, im in cells) + label_h + pad
    sheet.save(out)
    return True


def with_montage(rows, out: Path, height: int, title: str | None) -> bool:
    if not shutil.which('montage'):
        return False
    columns = max(len(r) for r in rows)
    files = []
    for r in rows:
        files += [str(f) for f in r] + ['null:'] * (columns - len(r))
    cmd = ['montage', '-label', '%f', *files, '-tile', f'{columns}x', '-geometry', f'x{height}+12+12',
           '-background', '#ECEEF1']
    if title:
        cmd += ['-title', title]
    return subprocess.run(cmd + [str(out)]).returncode == 0


def make_sheet(paths: list[str], out: str, height=480, columns=None, title=None) -> Path | None:
    images = collect(paths)
    if not images:
        return None
    base = Path(paths[0]) if len(paths) == 1 and Path(paths[0]).is_dir() else None
    rows = rows_of(images, columns)
    target = Path(out)
    target.parent.mkdir(parents=True, exist_ok=True)
    if with_pillow(rows, target, height, title, base) or with_montage(rows, target, height, title):
        return target
    raise SystemExit('sheet needs Pillow (pip install pillow) or ImageMagick (montage).')


def main(argv=None):
    p = argparse.ArgumentParser(prog='tool/codelessly sheet', description=__doc__.split('\n\n')[0])
    p.add_argument('inputs', nargs='+')
    p.add_argument('--out', required=True)
    p.add_argument('--height', type=int, default=480, help='each image scaled to at most this height (default 480)')
    p.add_argument('--columns', type=int)
    p.add_argument('--title')
    a = p.parse_args(argv)
    sheet = make_sheet(a.inputs, a.out, a.height, a.columns, a.title)
    if not sheet:
        print('No PNGs found.', file=sys.stderr)
        return 1
    print(f'wrote {sheet}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
