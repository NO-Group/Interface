#!/usr/bin/env python3
"""Generates every launcher icon for Interface Browser from scratch.

No external dependencies — pure Python (zlib/struct are stdlib).

Outputs:
  android/app/src/main/res/mipmap-*/ic_launcher.png        (48..192)
  android/app/src/main/res/mipmap-*/ic_launcher_round.png  (circle)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (108..432)
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher{,_round}.xml
  android/app/src/main/res/values/ic_launcher_background.xml
  windows/runner/resources/app_icon.ico                    (256, PNG-in-ICO)
  assets/brand/app_icon.png                                (512, source of truth)

Design: navy vertical-gradient rounded square + cyan globe with meridians.
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

NAVY_TOP = (0x10, 0x2A, 0x5C)
NAVY_BOT = (0x07, 0x18, 0x38)
CYAN = (53, 228, 255)

SS = 3  # supersampling grid (3x3 = 9 samples per pixel)


def lerp(a, b, t):
    return a + (b - a) * t


def clamp01(x):
    return 0.0 if x < 0 else (1.0 if x > 1 else x)


def sd_rounded_rect(px, py, s, r):
    cx = cy = s / 2.0
    qx = abs(px - cx) - (s / 2.0 - r)
    qy = abs(py - cy) - (s / 2.0 - r)
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def globe_ink(x, y, s):
    """Distance (in px) from (x,y) to the globe strokes. inf when far."""
    cx, cy = 0.5 * s, 0.5 * s
    R = 0.30 * s
    w = 0.055 * s
    dx, dy = x - cx, y - cy
    d = math.hypot(dx, dy)
    if d > R + w * 2.2:
        return float('inf')
    best = abs(d - R)
    # meridian ellipses: rx = 0.45R and 0.8R, ry = R
    for rx in (0.45 * R, 0.80 * R):
        e = math.hypot(dx / rx, dy / R)
        dist = abs(e - 1.0) * min(rx, R)
        if dist < best:
            best = dist
    # equator (clipped to circle interior)
    if d <= R:
        if abs(dy) < best:
            best = abs(dy)
    return best


def render_full(size, corner=None, circle=False):
    """Full icon: navy rounded bg + globe. Returns rows of RGBA bytes."""
    corner_r = corner if corner is not None else 0.20 * size
    rows = []
    half = 1.0 / (SS * 2)
    step = 1.0 / SS
    for py in range(size):
        row = bytearray(size * 4)
        for px in range(size):
            bg_a = 0.0
            r = g = b = 0.0
            ink_a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + half + sx * step
                    y = py + half + sy * step
                    if circle:
                        inside = math.hypot(x - size / 2, y - size / 2) <= size / 2
                    else:
                        inside = sd_rounded_rect(x, y, size, corner_r) <= 0
                    if inside:
                        t = y / size
                        bg_a += 1
                        r += lerp(NAVY_TOP[0], NAVY_BOT[0], t)
                        g += lerp(NAVY_TOP[1], NAVY_BOT[1], t)
                        b += lerp(NAVY_TOP[2], NAVY_BOT[2], t)
                    gd = globe_ink(x, y, size)
                    if gd < 0.023 * size:  # stroke half-width
                        ink_a += 1
            n = SS * SS
            ba = bg_a / n
            ia = ink_a / n
            # soft cyan glow just outside the strokes
            cr = cg = cb = ca = 0.0
            if ba > 0:
                cr = r / max(bg_a, 1e-6)
                cg = g / max(bg_a, 1e-6)
                cb = b / max(bg_a, 1e-6)
                ca = ba
            if ia > 0:
                cr = lerp(cr, CYAN[0], ia)
                cg = lerp(cg, CYAN[1], ia)
                cb = lerp(cb, CYAN[2], ia)
                ca = max(ca, min(1.0, ba + ia))
            row[px * 4 + 0] = int(clamp01(cr / 255.0) * 255.0)
            row[px * 4 + 1] = int(clamp01(cg / 255.0) * 255.0)
            row[px * 4 + 2] = int(clamp01(cb / 255.0) * 255.0)
            row[px * 4 + 3] = int(clamp01(ca) * 255)
        rows.append(row)
    return rows


def render_foreground(size):
    """Adaptive-icon foreground: globe only on transparent bg."""
    rows = []
    half = 1.0 / (SS * 2)
    step = 1.0 / SS
    for py in range(size):
        row = bytearray(size * 4)
        for px in range(size):
            ink = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + half + sx * step
                    y = py + half + sy * step
                    if globe_ink(x, y, size) < 0.026 * size:
                        ink += 1
            a = int(clamp01(ink / (SS * SS)) * 255)
            row[px * 4 + 0] = CYAN[0]
            row[px * 4 + 1] = CYAN[1]
            row[px * 4 + 2] = CYAN[2]
            row[px * 4 + 3] = a
        rows.append(row)
    return rows


def write_png(path, rows, w, h):
    def chunk(tag, data):
        return (
            struct.pack('>I', len(data))
            + tag
            + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    png = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', ihdr)
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b'')
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(png)
    print('wrote', path, f'({w}x{h})')


def write_ico(path, png_bytes):
    header = struct.pack('<HHH', 0, 1, 1)
    entry = struct.pack(
        '<BBBBHHII', 0, 0, 0, 0, 1, 32, len(png_bytes), 6 + 16
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(header + entry + png_bytes)
    print('wrote', path)


def main():
    densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
    }
    res = os.path.join(ROOT, 'android/app/src/main/res')
    for dpi, mult in densities.items():
        size = int(48 * mult)
        d = os.path.join(res, f'mipmap-{dpi}')
        write_png(os.path.join(d, 'ic_launcher.png'),
                  render_full(size), size, size)
        write_png(os.path.join(d, 'ic_launcher_round.png'),
                  render_full(size, circle=True), size, size)
        fg = int(108 * mult)
        write_png(os.path.join(d, 'ic_launcher_foreground.png'),
                  render_foreground(fg), fg, fg)

    # Adaptive icon XML (Android 8+) + monochrome for themed icons.
    anydpi = os.path.join(res, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
    with open(os.path.join(anydpi, 'ic_launcher.xml'), 'w') as f:
        f.write(adaptive)
    with open(os.path.join(anydpi, 'ic_launcher_round.xml'), 'w') as f:
        f.write(adaptive)
    print('wrote adaptive icon XMLs')

    values = os.path.join(res, 'values')
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, 'ic_launcher_background.xml'), 'w') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#0A1F44</color>\n'
            '</resources>\n'
        )
    print('wrote background color')

    # Windows .ico (single 256px PNG entry).
    ico_rows = render_full(256, corner=0.18 * 256)
    png_bytes = png_bytes_of(ico_rows, 256, 256)
    write_ico(os.path.join(ROOT, 'windows/runner/resources/app_icon.ico'),
              png_bytes)

    # Brand source icon.
    rows = render_full(512)
    write_png(os.path.join(ROOT, 'assets/brand/app_icon.png'), rows, 512, 512)


def png_bytes_of(rows, w, h):
    def chunk(tag, data):
        return (
            struct.pack('>I', len(data))
            + tag
            + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    return (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', ihdr)
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b'')
    )


if __name__ == '__main__':
    main()
