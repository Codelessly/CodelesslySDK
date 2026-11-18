"""Crops a PNG with no dependency (8-bit RGB or RGBA, not interlaced): the native builds' compare pictures hold
the native capture in their left half, under a caption band.

    python3 design_systems/desk/tool/crop_png.py <in.png> <out.png> <left> <top> <right> <bottom>

The box is in pixels; a value between 0 and 1 is a share of the width or height (0.5: the middle).
"""
import struct
import sys
import zlib


def read(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos, idat, w = 8, b"", 0
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and color in (2, 6) and interlace == 0, "8-bit RGB or RGBA, not interlaced"
            bpp = 3 if color == 2 else 4
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


def write(path, w, h, bpp, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    color = 2 if bpp == 3 else 6
    out = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    open(path, "wb").write(out)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    w, h, bpp, rows = read(src)

    def px(v, size):
        f = float(v)
        return int(round(f * size)) if 0 < f <= 1 and "." in v else int(f)

    l, t, r, b = px(sys.argv[3], w), px(sys.argv[4], h), px(sys.argv[5], w), px(sys.argv[6], h)
    rows = [row[l * bpp:r * bpp] for row in rows[t:b]]
    write(dst, r - l, b - t, bpp, rows)
    print(f"{dst}: {r - l}x{b - t}")


if __name__ == "__main__":
    main()
