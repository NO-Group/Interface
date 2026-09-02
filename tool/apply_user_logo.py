#!/usr/bin/env python3
"""Rebuilds every launcher icon from the user's uploaded logo.

Pure Python (zlib/struct only — no Pillow needed). Reads
assets/brand/app_logo.png and regenerates the same output set as
tool/gen_icons.py:

  android/app/src/main/res/mipmap-*/ic_launcher.png          (square, rounded)
  android/app/src/main/res/mipmap-*/ic_launcher_round.png    (circle)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (adaptive, 66%)
  windows/runner/resources/app_icon.ico                      (256, PNG-in-ICO)
  assets/brand/app_icon.png                                  (512, in-app use)
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/brand/app_logo.png')

# mipmap density -> legacy/round px size, adaptive foreground px size
DENSITIES = [
    ('mdpi', 48, 108),
    ('hdpi', 72, 162),
    ('xhdpi', 96, 216),
    ('xxhdpi', 144, 324),
    ('xxxhdpi', 192, 432),
]

NAVY = (0x0A, 0x1F, 0x44)


# ---------------------------------------------------------------- PNG decode

def decode_png(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'not a PNG'
    off = 8
    w = h = bd = ct = il = None
    idat = []
    while off < len(data):
        ln = struct.unpack('>I', data[off:off + 4])[0]
        typ = data[off + 4:off + 8]
        body = data[off + 8:off + 8 + ln]
        if typ == b'IHDR':
            w, h, bd, ct, _cm, _fm, il = struct.unpack('>IIBBBBB', body)
        elif typ == b'IDAT':
            idat.append(body)
        elif typ == b'IEND':
            break
        off += 12 + ln
    assert il == 0, 'interlaced PNG not supported'
    assert bd == 8, 'only 8-bit PNGs supported'
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    raw = zlib.decompress(b''.join(idat))
    stride = w * channels
    out = bytearray(w * h * 4)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        f = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if f == 1:  # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif f == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:  # Average
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif f == 4:  # Paeth
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        # expand to RGBA
        ro = y * w * 4
        if ct == 6:
            out[ro:ro + w * 4] = line
        elif ct == 2:
            for x in range(w):
                o = x * 3
                out[ro + x * 4:ro + x * 4 + 3] = line[o:o + 3]
                out[ro + x * 4 + 3] = 255
        elif ct == 4:
            for x in range(w):
                g = line[x * 2]
                out[ro + x * 4:ro + x * 4 + 3] = bytes((g, g, g))
                out[ro + x * 4 + 3] = line[x * 2 + 1]
        elif ct == 0:
            for x in range(w):
                g = line[x]
                out[ro + x * 4:ro + x * 4 + 3] = bytes((g, g, g))
                out[ro + x * 4 + 3] = 255
        else:
            raise AssertionError('palette PNG not supported')
        prev = line
    return w, h, bytes(out)


# ---------------------------------------------------------------- PNG encode

def encode_png(w, h, rgba):
    def chunk(typ, body):
        return (struct.pack('>I', len(body)) + typ + body +
                struct.pack('>I', zlib.crc32(typ + body) & 0xFFFFFFFF))

    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)  # filter: none
        raw += rgba[y * stride:(y + 1) * stride]
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) +
            chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))


# ------------------------------------------------------------- scaling etc.

def downscale(src, sw, sh, dw, dh):
    """Alpha-weighted box downscale. Returns RGBA bytes."""
    out = bytearray(dw * dh * 4)
    for dy in range(dh):
        y0 = dy * sh // dh
        y1 = max(y0 + 1, (dy + 1) * sh // dh)
        for dx in range(dw):
            x0 = dx * sw // dw
            x1 = max(x0 + 1, (dx + 1) * sw // dw)
            r = g = b = a = n = 0
            for y in range(y0, y1):
                row = (y * sw + x0) * 4
                for _x in range(x0, x1):
                    al = src[row + 3]
                    r += src[row] * al
                    g += src[row + 1] * al
                    b += src[row + 2] * al
                    a += al
                    n += 1
                    row += 4
            o = (dy * dw + dx) * 4
            if a == 0:
                out[o:o + 4] = b'\x00\x00\x00\x00'
            else:
                out[o] = min(255, r // a)
                out[o + 1] = min(255, g // a)
                out[o + 2] = min(255, b // a)
                out[o + 3] = a // n
    return bytes(out)


def rounded_square(rgba, size, radius_frac=0.0, circle=False):
    """Applies a rounded-corner (or circular) alpha mask, navy backing for
    fully transparent pixels so legacy launchers never show holes."""
    r = size * radius_frac * 0.5 if not circle else 0
    cx = cy = (size - 1) / 2
    cr = size / 2 - 0.5
    out = bytearray(rgba)
    for y in range(size):
        for x in range(size):
            if circle:
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                inside = d <= cr - 0.5
                edge = cr - 0.5 < d <= cr + 0.5
                cov = 1 - (d - (cr - 0.5)) / 2 if edge else (1.0 if inside else 0.0)
            else:
                cov = _rounded_cov(x, y, size, r)
            o = (y * size + x) * 4
            if cov <= 0:
                out[o:o + 4] = b'\x00\x00\x00\x00'
            else:
                out[o + 3] = int(rgba[o + 3] * cov)
    return bytes(out)


def _rounded_cov(x, y, size, r):
    """Anti-aliased coverage of a rounded-rectangle mask (4x4 samples)."""
    if r <= 0:
        return 1.0
    hit = 0
    for sy in (0.125, 0.375, 0.625, 0.875):
        for sx in (0.125, 0.375, 0.625, 0.875):
            px, py = x + sx, y + sy
            dx = dy = 0.0
            if px < r:
                dx = r - px
            elif px > size - r:
                dx = px - (size - r)
            if py < r:
                dy = r - py
            elif py > size - r:
                dy = py - (size - r)
            if dx * dx + dy * dy <= r * r:
                hit += 1
    return hit / 16


def pad_centered(rgba, size, canvas):
    """Places a size×size image centered on a transparent canvas×canvas."""
    out = bytearray(canvas * canvas * 4)
    off = (canvas - size) // 2
    for y in range(size):
        src = y * size * 4
        dst = ((off + y) * canvas + off) * 4
        out[dst:dst + size * 4] = rgba[src:src + size * 4]
    return bytes(out)


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)
    print(f'  {os.path.relpath(path, ROOT)}  ({len(data)} bytes)')


def crop_to_mark(src, w, h, pad_frac=0.02):
    """Crops transparent margins so the mark fills the canvas."""
    xmin, ymin, xmax, ymax = w, h, 0, 0
    for y in range(h):
        row = y * w * 4
        for x in range(w):
            if src[row + x * 4 + 3] > 12:
                if x < xmin: xmin = x
                if x > xmax: xmax = x
                if y < ymin: ymin = y
                if y > ymax: ymax = y
    if xmax <= xmin or ymax <= ymin:
        return src, w, h
    pad = int(max(xmax - xmin, ymax - ymin) * pad_frac)
    xmin = max(0, xmin - pad); ymin = max(0, ymin - pad)
    xmax = min(w - 1, xmax + pad); ymax = min(h - 1, ymax + pad)
    cw, ch = xmax - xmin + 1, ymax - ymin + 1
    out = bytearray(cw * ch * 4)
    for y in range(ch):
        s = ((ymin + y) * w + xmin) * 4
        out[y * cw * 4:(y + 1) * cw * 4] = src[s:s + cw * 4]
    return bytes(out), cw, ch


def composite_mark(canvas_size, mark, mw, mh, box_frac, transparent_bg=False):
    """Alpha-composites the mark (aspect kept) centered on a canvas."""
    box = canvas_size * box_frac
    tw = max(1, round(box)); th = max(1, round(box * mh / mw))
    if th > box:
        th = max(1, round(box)); tw = max(1, round(box * mw / mh))
    tile = downscale(mark, mw, mh, tw, th)
    out = bytearray(canvas_size * canvas_size * 4)
    if not transparent_bg:
        for i in range(canvas_size * canvas_size):
            out[i * 4:i * 4 + 4] = b'\x0a\x1f\x44\xff'
    ox = (canvas_size - tw) // 2
    oy = (canvas_size - th) // 2
    for y in range(th):
        for x in range(tw):
            si = (y * tw + x) * 4
            a = tile[si + 3]
            if a == 0:
                continue
            di = ((oy + y) * canvas_size + (ox + x)) * 4
            if a == 255:
                out[di:di + 4] = tile[si:si + 4]
            else:
                da = out[di + 3]
                sa = a / 255
                out[di] = int(tile[si] * sa + out[di] * (1 - sa) * da / 255)
                out[di + 1] = int(tile[si + 1] * sa + out[di + 1] * (1 - sa) * da / 255)
                out[di + 2] = int(tile[si + 2] * sa + out[di + 2] * (1 - sa) * da / 255)
                out[di + 3] = int(a + da * (1 - sa))
    return bytes(out)


def main():
    print(f'Reading {os.path.relpath(SRC, ROOT)}…')
    w, h, src = decode_png(open(SRC, 'rb').read())
    print(f'  {w}x{h} RGBA')
    mark, mw, mh = crop_to_mark(src, w, h)
    print(f'  mark cropped to {mw}x{mh}')

    # Keep the maths cheap: work from a 640px-wide mark master.
    if mw > 640:
        mark = downscale(mark, mw, mh, 640, round(640 * mh / mw))
        mh = round(640 * mh / mw); mw = 640

    print('Android launchers:')
    res = os.path.join(ROOT, 'android/app/src/main/res')
    for name, size, fg_size in DENSITIES:
        base = composite_mark(size, mark, mw, mh, 0.74)
        write(os.path.join(res, f'mipmap-{name}/ic_launcher.png'),
              encode_png(size, size, rounded_square(base, size, 0.22)))
        write(os.path.join(res, f'mipmap-{name}/ic_launcher_round.png'),
              encode_png(size, size, rounded_square(base, size, circle=True)))
        fg = composite_mark(fg_size, mark, mw, mh, 0.46, transparent_bg=True)
        write(os.path.join(res, f'mipmap-{name}/ic_launcher_foreground.png'),
              encode_png(fg_size, fg_size, fg))

    print('In-app icon:')
    write(os.path.join(ROOT, 'assets/brand/app_icon.png'),
          encode_png(512, 512,
                     rounded_square(composite_mark(512, mark, mw, mh, 0.74), 512, 0.22)))

    print('Windows icon:')
    ico = encode_png(256, 256,
                     rounded_square(composite_mark(256, mark, mw, mh, 0.74), 256, 0.22))
    entry = struct.pack('<BBBBHHII', 0, 0, 0, 0, 1, 32, len(ico), 22)
    header = struct.pack('<HHH', 0, 1, 1)
    write(os.path.join(ROOT, 'windows/runner/resources/app_icon.ico'),
          header + entry + ico)

    print('Done — every launcher now uses the uploaded logo.')


if __name__ == '__main__':
    main()
