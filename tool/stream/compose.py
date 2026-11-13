#!/usr/bin/env python3
"""Turns a replay's captured frames into a video with an overlay strip and a
contact sheet. Usage: compose.py <replay size dir> (with frames.json).

Writes video.mp4 (H.264, 10 fps; desktop sizes scaled to 960 wide) and
contact.png (the frames at 5, 15, 30, 50, 75 and 100% of the time to
complete), then removes the raw frames."""
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

STRIP = 44


def font(size):
    for path in ['/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf',
                 '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def label(meta, metrics):
    src = meta.get('source', '')
    if src == 'live':
        what = meta.get('model', 'live')
    else:
        what = f"{meta.get('rateTokensPerSecond', '?')} tok/s"
    return f"{meta.get('ui', '')} · {what}"


def overlay(img, fr, total_tokens, meta, metrics, scale):
    w, h = img.size
    out = Image.new('RGB', (w, h + STRIP), (15, 23, 42))
    out.paste(img.convert('RGB'), (0, 0))
    d = ImageDraw.Draw(out)
    f = font(13 if w < 600 else 15)
    t = fr['tMs'] / 1000
    tok = fr['tokens']
    text = f"{t:5.1f} s   {tok:>5} tok   {fr['nodes']:>3} nodes"
    d.text((10, h + 6), text, fill=(226, 232, 240), font=f)
    lab = label(meta, metrics)
    tw = d.textlength(lab, font=f)
    d.text((w - tw - 10, h + 6), lab, fill=(148, 163, 184), font=f)
    # Tokens received.
    frac = 0 if total_tokens == 0 else min(1, tok / total_tokens)
    d.rectangle([10, h + STRIP - 12, w - 10, h + STRIP - 8], fill=(51, 65, 85))
    d.rectangle([10, h + STRIP - 12, 10 + (w - 20) * frac, h + STRIP - 8], fill=(56, 189, 248))
    if scale != 1:
        out = out.resize((int(out.width * scale) // 2 * 2, int(out.height * scale) // 2 * 2), Image.LANCZOS)
    elif out.width % 2 or out.height % 2:
        out = out.crop((0, 0, out.width // 2 * 2, out.height // 2 * 2))
    return out


def main(d):
    data = json.load(open(os.path.join(d, 'frames.json')))
    frames, meta, metrics = data['frames'], data['meta'], data['metrics']
    total_tokens = metrics.get('outputTokens') or 0
    first = Image.open(frames[0]['file'])
    scale = 1 if first.width <= 600 else 960 / first.width
    tmp = tempfile.mkdtemp()
    try:
        composed = []
        for i, fr in enumerate(frames):
            im = overlay(Image.open(fr['file']), fr, total_tokens, meta, metrics, scale)
            p = os.path.join(tmp, f'c{i:04d}.png')
            im.save(p)
            composed.append((fr, im))
        # Hold the last frame a second.
        for k in range(10):
            composed[-1][1].save(os.path.join(tmp, f'c{len(frames) + k:04d}.png'))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '10', '-i', os.path.join(tmp, 'c%04d.png'),
                        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '30', '-preset', 'slow', '-movflags', '+faststart',
                        os.path.join(d, 'video.mp4')], check=True)
        # Contact sheet.
        done = metrics.get('timeToCompleteMs') or frames[-1]['tMs']
        picks = []
        for pct in [5, 15, 30, 50, 75, 100]:
            target = done * pct / 100
            best = min(frames, key=lambda f: abs(f['tMs'] - target) if f['tMs'] <= target + 1 or pct == 100 else 1e12)
            if pct == 100:
                best = frames[-1]
            picks.append((pct, best))
        thumbs = []
        tw = 260 if first.width <= 600 else 480
        for pct, fr in picks:
            im = overlay(Image.open(fr['file']), fr, total_tokens, meta, metrics, 1)
            im = im.resize((tw, int(im.height * tw / im.width)), Image.LANCZOS)
            thumbs.append((pct, im))
        cols = 6 if first.width <= 600 else 3
        rows = (len(thumbs) + cols - 1) // cols
        th = thumbs[0][1].height
        sheet = Image.new('RGB', (cols * (tw + 12) + 12, rows * (th + 34) + 50), (248, 250, 252))
        dr = ImageDraw.Draw(sheet)
        title = (f"{label(meta, metrics)} · {metrics['size']} · first paint {metrics.get('timeToFirstPaintMs')} ms · "
                 f"first section {metrics.get('timeToFirstSectionMs')} ms · complete {metrics.get('timeToCompleteMs')} ms · "
                 f"{metrics.get('outputTokens')} tok")
        dr.text((12, 14), title, fill=(15, 23, 42), font=font(15))
        for i, (pct, im) in enumerate(thumbs):
            x = 12 + (i % cols) * (tw + 12)
            y = 50 + (i // cols) * (th + 34)
            dr.text((x, y), f'{pct}%', fill=(71, 85, 105), font=font(13))
            sheet.paste(im, (x, y + 20))
        sheet.save(os.path.join(d, 'contact.png'), optimize=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.rmtree(os.path.join(d, 'frames'), ignore_errors=True)
        # frames.json pointed at the removed frames: keep the timeline only.
        for fr in frames:
            fr.pop('file', None)
        json.dump(data, open(os.path.join(d, 'frames.json'), 'w'))


if __name__ == '__main__':
    main(sys.argv[1])
