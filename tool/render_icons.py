#!/usr/bin/env python3
"""Rasterise the UI icon set into a contact sheet so it can be reviewed.

The app draws these SVGs through flutter_svg; this is a second, independent
renderer for the small subset of SVG the generator emits (M, L, C, Z with a
uniform round-capped stroke). It exists so the drawings can be looked at and
measured without a Flutter toolchain.

    python3 tool/render_icons.py                # design/icon-sheet.png
    python3 tool/render_icons.py --one reload   # /tmp/one.png at 384px
    python3 tool/render_icons.py --grid 12 --size 96
"""
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, 'assets', 'icons')

SS = 3  # samples per pixel edge
NUM = re.compile(r'-?\d*\.?\d+')


# --------------------------------------------------------------------- paths
def parse_path(d):
    """Yield subpaths: each is a list of (x, y) plus a closed flag."""
    toks = re.findall(r'[MLCZ]|-?\d*\.?\d+', d)
    subs, cur, i = [], [], 0
    cmd = None
    nums = []

    def flush():
        nonlocal cur
        if len(cur) > 1:
            subs.append((cur, closed))
        cur = []

    while i < len(toks):
        t = toks[i]
        if not t[0].isdigit() and t[0] != '-':
            if t == 'Z':
                closed = True
                if cur:
                    cur.append(cur[0])
                flush()
                i += 1
                continue
            cmd = t
            i += 1
            nums = []
            continue
        if cmd == 'M':
            x, y = float(toks[i]), float(toks[i + 1])
            closed = False
            flush()
            cur = [(x, y)]
            i += 2
            cmd = 'L'
        elif cmd == 'L':
            x, y = float(toks[i]), float(toks[i + 1])
            cur.append((x, y))
            i += 2
        elif cmd == 'C':
            p0 = cur[-1] if cur else (0.0, 0.0)
            c1 = (float(toks[i]), float(toks[i + 1]))
            c2 = (float(toks[i + 2]), float(toks[i + 3]))
            p1 = (float(toks[i + 4]), float(toks[i + 5]))
            steps = 26
            for s in range(1, steps + 1):
                t = s / steps
                mt = 1 - t
                x = (mt ** 3 * p0[0] + 3 * mt * mt * t * c1[0] +
                     3 * mt * t * t * c2[0] + t ** 3 * p1[0])
                y = (mt ** 3 * p0[1] + 3 * mt * mt * t * c1[1] +
                     3 * mt * t * t * c2[1] + t ** 3 * p1[1])
                cur.append((x, y))
            i += 6
        elif cmd == 'Z':
            closed = True
            if cur:
                cur.append(cur[0])
            flush()
            i += 1
        else:
            i += 1
    flush()
    return subs


def read_svg(path):
    raw = open(path).read()
    out = []
    for m in re.finditer(r'<path[^>]*/>', raw):
        tag = m.group(0)

        def attr(name, default=None):
            mm = re.search(name + r'="([^"]*)"', tag)
            return mm.group(1) if mm else default

        d = attr('d', '')
        if not d:
            continue
        fill = attr('fill', 'none')
        stroke = attr('stroke')
        w = float(attr('stroke-width', '1.7'))
        fo = float(attr('fill-opacity', '1'))
        out.append(dict(d=d, fill=fill if fill != 'none' else None,
                        stroke=stroke, w=w, fo=fo))
    return out


# ----------------------------------------------------------------- rasterise
def draw(paths, size, bg, fg, ss=SS):
    """Return size*size rows of (r, g, b) with the glyph painted in fg."""
    scale = size / 24.0
    S = size * ss
    strokes = [p for p in paths if p['stroke']]
    fills = [p for p in paths if p['fill']]

    # strokes: capsule distance, fills: even-odd scanline; each shape keeps
    # its own weight so a soft fill stays soft.
    acc = [[0.0] * S for _ in range(S)]
    for p in strokes:
        subs = parse_path(p['d'])
        h = p['w'] * scale * ss / 2.0
        for pts, _closed in subs:
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                ax, ay = x0 * scale * ss, y0 * scale * ss
                bx, by = x1 * scale * ss, y1 * scale * ss
                dx, dy = bx - ax, by - ay
                L2 = dx * dx + dy * dy
                lo = max(0, int(min(ax, bx) - h) - 1)
                hi = min(S - 1, int(max(ax, bx) + h) + 1)
                lo2 = max(0, int(min(ay, by) - h) - 1)
                hi2 = min(S - 1, int(max(ay, by) + h) + 1)
                for py in range(lo2, hi2 + 1):
                    for px in range(lo, hi + 1):
                        cx, cy = px + 0.5, py + 0.5
                        t = 0.0 if L2 == 0 else ((cx - ax) * dx +
                                                 (cy - ay) * dy) / L2
                        t = 0.0 if t < 0 else (1.0 if t > 1 else t)
                        qx, qy = ax + t * dx - cx, ay + t * dy - cy
                        dist2 = qx * qx + qy * qy
                        if dist2 <= (h + 0.5) ** 2:
                            v = 1.0 if dist2 < (h - 0.5) ** 2 else 0.5 - ((
                                dist2 ** 0.5) - h)
                            acc[py][px] = max(acc[py][px], min(1.0, v))

    # fills: even-odd scanline on the supersampled grid
    for p in fills:
        subs = parse_path(p['d'])
        for pts, _closed in subs:
            ys = [int(y * scale * ss) for _x, y in pts]
            if not ys:
                continue
            y0, y1 = max(0, min(ys) - 1), min(S - 1, max(ys) + 1)
            xs = [x * scale * ss for x, _y in pts]
            xlo, xhi = max(0, int(min(xs)) - 1), min(S - 1, int(max(xs)) + 1)
            n = len(pts)
            for py in range(y0, y1 + 1):
                yy = py + 0.5
                xints = []
                for i in range(n - 1):
                    ax, ay = pts[i][0] * scale * ss, pts[i][1] * scale * ss
                    bx, by = pts[i + 1][0] * scale * ss, pts[i + 1][1] * scale * ss
                    if (ay > yy) == (by > yy):
                        continue
                    t = (yy - ay) / (by - ay)
                    xints.append(ax + t * (bx - ax))
                xints.sort()
                for k in range(0, len(xints) - 1, 2):
                    a = max(xlo, int(xints[k]))
                    b = min(xhi, int(xints[k + 1]))
                    for px in range(a, b + 1):
                        acc[py][px] = max(acc[py][px], p['fo'])

    rows = []
    area = float(ss * ss)
    for y in range(size):
        row = []
        for x in range(size):
            a = 0.0
            for sy in range(ss):
                base = acc[y * ss + sy]
                for sx in range(ss):
                    a += min(1.0, base[x * ss + sx])
            t = a / area
            if t <= 0:
                row.append(bg)
            else:
                if t > 1:
                    t = 1.0
                row.append(tuple(int(bg[i] * (1 - t) + fg[i] * t) for i in range(3)))
        rows.append(row)
    return rows


def write_png(path, rows, w, h):
    raw = b''.join(b'\x00' + bytes(c for px in row for c in px) for row in rows)

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data +
                struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))

    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
        f.write(chunk(b'IEND', b''))


def sheet(cols=12, tile=96, bg=(22, 35, 63), fg=(226, 240, 250), gap=10,
          out='/tmp/icons-sheet.png', names=None, scale_preview=1.0):
    files = sorted(f[:-4] for f in os.listdir(ICONS) if f.endswith('.svg'))
    if names:
        files = [f for f in files if f in names]
    rows = (len(files) + cols - 1) // cols
    W = cols * tile + (cols + 1) * gap
    H = rows * (tile + 22) + gap
    canvas = [[bg for _ in range(W)] for _ in range(H)]
    for idx, name in enumerate(files):
        paths = read_svg(os.path.join(ICONS, name + '.svg'))
        tile_rows = draw(paths, tile, bg, fg)
        r, c = divmod(idx, cols)
        y0 = gap + r * (tile + 22) + 18
        x0 = gap + c * (tile + gap)
        for y in range(tile):
            for x in range(tile):
                canvas[y0 + y][x0 + x] = tile_rows[y][x]
    write_png(out, canvas, W, H)
    per = ', '.join(files)
    print(f'{len(files)} icons -> {out}  ({W}x{H})')
    print('order: ' + per)
    return out


def main():
    args = sys.argv[1:]
    if '--one' in args:
        name = args[args.index('--one') + 1]
        paths = read_svg(os.path.join(ICONS, name + '.svg'))
        rows = draw(paths, 384, (16, 26, 48), (230, 244, 255))
        write_png('/tmp/one.png', rows, 384, 384)
        print('/tmp/one.png')
        return
    cols = int(args[args.index('--grid') + 1]) if '--grid' in args else 12
    tile = int(args[args.index('--size') + 1]) if '--size' in args else 96
    out = args[args.index('--out') + 1] if '--out' in args else '/tmp/icons-sheet.png'
    sheet(cols=cols, tile=tile, out=out)


if __name__ == '__main__':
    main()
