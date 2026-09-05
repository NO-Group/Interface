#!/usr/bin/env python3
"""Interface's UI icon set: 115 glyphs authored on a 24pt grid.

Each icon is line work with one deliberate imperfection - a chamfered corner
on containers - which is the same corner language the chrome uses, so the
icons and the window read as one family. Icons ship as SVG in `assets/icons/`
and are recoloured at runtime with a src-in blend: everything is drawn in
#000 and the colour comes from the surrounding text.

    python3 tool/gen_ui_icons.py            # check the drawings
    python3 tool/gen_ui_icons.py --emit     # write assets/icons/*.svg
    python3 tool/gen_ui_icons.py --sheet    # list the names

House rules, all enforced by --qa:
  * 24 x 24 box, 2.4pt of air on each side, optical centre at (12, 12).
  * one primary weight (1.7) and one lighter detail weight (1.35).
  * round caps, round joins, closed silhouettes for fills.
  * no SVG arc commands: curves come out as cubic Beziers, which the renderer
    in use draws exactly.
"""
import math
import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'icons')

SW, SD = 1.7, 1.35     # primary and detail weights
RAD = 3.2              # container corner
CUT = 5.8              # chamfer that replaces one corner
K = 0.5522847          # circle-to-cubic constant
EDGE = (2.0, 22.0)     # the live area


# --------------------------------------------------------------- geometry --
def n(v):
    s = f'{v:.2f}'.rstrip('0').rstrip('.')
    return '0' if s in ('', '-0') else s


def P(*pts):
    """Move through points."""
    return 'M ' + ' L '.join(f'{n(x)} {n(y)}' for x, y in pts)


def poly(pts):
    return P(*pts) + ' Z'


def seg(x1, y1, x2, y2):
    return f'M {n(x1)} {n(y1)} L {n(x2)} {n(y2)}'


def join(*paths):
    """Chain open paths into one stroke, assuming the ends meet."""
    out = paths[0]
    for p in paths[1:]:
        out += ' L ' + p.split(' ', 1)[1] if p.startswith('M ') else out + ' ' + p
    return out


def circle(cx, cy, r):
    k = r * K
    return (
        f'M {n(cx - r)} {n(cy)} '
        f'C {n(cx - r)} {n(cy - k)} {n(cx - k)} {n(cy - r)} {n(cx)} {n(cy - r)} '
        f'C {n(cx + k)} {n(cy - r)} {n(cx + r)} {n(cy - k)} {n(cx + r)} {n(cy)} '
        f'C {n(cx + r)} {n(cy + k)} {n(cx + k)} {n(cy + r)} {n(cx)} {n(cy + r)} '
        f'C {n(cx - k)} {n(cy + r)} {n(cx - r)} {n(cy + k)} {n(cx - r)} {n(cy)} Z'
    )


def ellipse(cx, cy, rx, ry):
    kx, ky = rx * K, ry * K
    return (
        f'M {n(cx - rx)} {n(cy)} '
        f'C {n(cx - rx)} {n(cy - ky)} {n(cx - kx)} {n(cy - ry)} {n(cx)} {n(cy - ry)} '
        f'C {n(cx + kx)} {n(cy - ry)} {n(cx + rx)} {n(cy - ky)} {n(cx + rx)} {n(cy)} '
        f'C {n(cx + rx)} {n(cy + ky)} {n(cx + kx)} {n(cy + ry)} {n(cx)} {n(cy + ry)} '
        f'C {n(cx - kx)} {n(cy + ry)} {n(cx - rx)} {n(cy + ky)} {n(cx - rx)} {n(cy)} Z'
    )


def arc(cx, cy, r, a0, a1, max_deg=45):
    """Circular arc from a0 to a1 in degrees, as cubic Beziers."""
    span = math.radians(a1 - a0)
    steps = max(2, int(abs(span) / math.radians(max_deg)) + 1)
    dphi = span / steps
    f = 4.0 / 3.0 * math.tan(dphi / 4.0)
    d = ''
    px = py = None
    for i in range(steps + 1):
        phi = math.radians(a0) + dphi * i
        x, y = cx + r * math.cos(phi), cy + r * math.sin(phi)
        if px is None:
            d = f'M {n(x)} {n(y)}'
        else:
            q = math.radians(a0) + dphi * (i - 1)
            c1 = (px - r * f * math.sin(q), py + r * f * math.cos(q))
            c2 = (x + r * f * math.sin(phi), y - r * f * math.cos(phi))
            d += (f' C {n(c1[0])} {n(c1[1])} {n(c2[0])} {n(c2[1])} '
                  f'{n(x)} {n(y)}')
        px, py = x, y
    return d


def rr(x, y, w, h, r=RAD, cut=None):
    """Rounded rectangle with an optional chamfer on one corner."""
    r = min(r, w / 2.0, h / 2.0)
    c = CUT if cut else 0.0
    x2, y2 = x + w, y + h
    k = r * K
    top_end = x2 - (c if cut == 'tr' else r)
    right_end = y2 - (c if cut == 'br' else r)
    bot_start = x + (c if cut == 'bl' else r)
    d = ''
    # top-left
    if cut == 'tl':
        d += f'M {n(x)} {n(y + c)} L {n(x + c)} {n(y)} '
    else:
        d += (f'M {n(x)} {n(y + r)} C {n(x)} {n(y + r - k)} '
              f'{n(x + r - k)} {n(y)} {n(x + r)} {n(y)} ')
    # top edge + top-right
    d += f'L {n(top_end)} {n(y)} '
    if cut == 'tr':
        d += f'L {n(x2)} {n(y + c)} '
    else:
        d += (f'C {n(x2 - r + k)} {n(y)} {n(x2)} {n(y + r - k)} '
              f'{n(x2)} {n(y + r)} ')
    # right edge + bottom-right
    d += f'L {n(x2)} {n(right_end)} '
    if cut == 'br':
        d += f'L {n(x2 - c)} {n(y2)} '
    else:
        d += (f'C {n(x2)} {n(y2 - r + k)} {n(x2 - r + k)} {n(y2)} '
              f'{n(x2 - r)} {n(y2)} ')
    # bottom edge + bottom-left
    d += f'L {n(bot_start)} {n(y2)} '
    if cut == 'bl':
        d += f'L {n(x)} {n(y2 - c)} '
    else:
        d += (f'C {n(x + r - k)} {n(y2)} {n(x)} {n(y2 - r + k)} {n(x)} '
              f'{n(y2 - r)} ')
    return d + 'Z'


def star(cx, cy, ro, ri, points=5, rot=-90.0):
    pts = []
    for i in range(points * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + i * 180.0 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def chevron(cx, cy, direction, s=3.4):
    if direction == 'left':
        return P((cx + s * 0.55, cy - s), (cx - s * 0.55, cy),
                 (cx + s * 0.55, cy + s))
    if direction == 'right':
        return P((cx - s * 0.55, cy - s), (cx + s * 0.55, cy),
                 (cx - s * 0.55, cy + s))
    if direction == 'up':
        return P((cx - s, cy + s * 0.55), (cx, cy - s * 0.55),
                 (cx + s, cy + s * 0.55))
    return P((cx - s, cy - s * 0.55), (cx, cy + s * 0.55),
             (cx + s, cy - s * 0.55))


def head(x, y, direction, s=3.3):
    """An arrow head pointing at (x, y)."""
    if direction == 'left':
        return P((x + s, y - s), (x, y), (x + s, y + s))
    if direction == 'right':
        return P((x - s, y - s), (x, y), (x - s, y + s))
    if direction == 'up':
        return P((x - s, y + s), (x, y), (x + s, y + s))
    return P((x - s, y - s), (x, y), (x + s, y - s))


# Document silhouette: a page with the family chamfer, plus the short stroke
# that turns the chamfer into a folded corner.
PX, PY, PW, PH = 4.4, 3.0, 15.2, 18.0


def page():
    return rr(PX, PY, PW, PH, RAD, 'tr')


def fold():
    return seg(PX + PW - CUT, PY, PX + PW, PY + CUT)


def folder(x=2.6, y=5.4, w=18.8, h=13.6, tab=6.6, step=3.2):
    """Folder with a tab, chamfer where the tab meets the body."""
    x2, y2 = x + w, y + h
    r = 2.6
    k = r * K
    return (
        f'M {n(x + r)} {n(y)} L {n(x + tab)} {n(y)} '
        f'L {n(x + tab + 2.0)} {n(y + step)} '
        f'L {n(x2 - r)} {n(y + step)} '
        f'C {n(x2 - r + k)} {n(y + step)} {n(x2)} {n(y + step + r - k)} '
        f'{n(x2)} {n(y + step + r)} '
        f'L {n(x2)} {n(y2 - r)} '
        f'C {n(x2)} {n(y2 - r + k)} {n(x2 - r + k)} {n(y2)} {n(x2 - r)} {n(y2)} '
        f'L {n(x + r)} {n(y2)} '
        f'C {n(x + r - k)} {n(y2)} {n(x)} {n(y2 - r + k)} {n(x)} {n(y2 - r)} '
        f'L {n(x)} {n(y + r)} '
        f'C {n(x)} {n(y + r - k)} {n(x + r - k)} {n(y)} {n(x + r)} {n(y)} Z'
    )


def magnifier(cx=10.6, cy=10.6, r=5.6, hx=19.4, hy=19.4):
    return [('s', circle(cx, cy, r), SW),
            ('s', seg(cx + r * 0.71, cy + r * 0.71, hx, hy), SW)]


def shield(cy=12.4):
    """Shield: flat-topped shoulders, a pointed base."""
    return join(arc(12, cy, 7.8, 20, 160, 40),
                P((12 - 7.8 * math.cos(math.radians(20)),
                   cy + 7.8 * math.sin(math.radians(20))),
                  (4.2, 6.2), (12, 3.2), (19.8, 6.2),
                  (12 + 7.8 * math.cos(math.radians(20)),
                   cy + 7.8 * math.sin(math.radians(20)))))


# ------------------------------------------------------------- the drawings --
# (s) stroke   (f) solid fill   (o) soft fill at 18%
D = {}


def def_(name, shapes):
    D[name] = shapes


def S(d, w=SW):
    return ('s', d, w)


def Fl(d):
    return ('f', d, 0.0)


def Of(d):
    return ('o', d, 0.0)


# -- navigation
def_('back', [S(seg(19.4, 12, 5.0, 12)), S(head(5.0, 12, 'left'))])
def_('forward', [S(seg(4.6, 12, 19.0, 12)), S(head(19.0, 12, 'right'))])
def_('up', [S(seg(12, 19.4, 12, 5.4)), S(head(12, 5.4, 'up'))])
def_('arrow-up', [S(seg(12, 19.6, 12, 4.4)), S(head(12, 4.4, 'up', 3.6)),
                  S(seg(7.6, 8.4, 16.4, 8.4), SD)])
def_('arrow-down', [S(seg(12, 4.4, 12, 19.6)), S(head(12, 19.6, 'down', 3.6)),
                    S(seg(7.6, 15.6, 16.4, 15.6), SD)])
def_('chevron-up', [S(chevron(12, 12.6, 'up', 3.6))])
def_('chevron-down', [S(chevron(12, 11.4, 'down', 3.6))])
def_('chevron-left', [S(chevron(12.6, 12, 'left', 3.6))])
def_('chevron-right', [S(chevron(11.4, 12, 'right', 3.6))])
def_('home', [S(rr(5.4, 10.0, 13.2, 10.6, 2.8)),
              S(P((3.4, 10.6), (12, 3.2), (20.6, 10.6))),
              S(rr(10.2, 13.6, 3.6, 7.0, 1.4, 'tl'), SD)])
def_('reload', [S(arc(12, 12, 7.8, -46, 214, 40)),
                S(P((18.0, 5.4), (19.4, 10.2), (14.6, 11.2)))])
def_('restart', [S(arc(12, 12, 7.8, -46, 214, 40)),
                 S(P((18.0, 5.4), (19.4, 10.2), (14.6, 11.2))),
                 S(seg(12, 8.4, 12, 12.4), SD),
                 S(seg(12, 12.4, 14.9, 13.9), SD)])
def_('restore', [S(rr(4.0, 10.8, 16.0, 8.4, 2.6)),
                 S(seg(12, 9.0, 12, 3.2)), S(head(12, 3.2, 'up', 3.0))])
def_('stop', [S(circle(12, 12, 8.0)), S(seg(9.2, 9.2, 14.8, 14.8), SD),
              S(seg(14.8, 9.2, 9.2, 14.8), SD)])
def_('menu', [S(seg(4.2, 7.2, 19.8, 7.2)), S(seg(4.2, 12, 19.8, 12)),
              S(seg(4.2, 16.8, 14.6, 16.8))])
def_('dots', [S(circle(12, 5.0, 1.3)), S(circle(12, 12, 1.3)),
              S(circle(12, 19.0, 1.3))])
def_('expand', [S(P((13.4, 4.6), (19.4, 4.6), (19.4, 10.6))),
                S(P((10.6, 19.4), (4.6, 19.4), (4.6, 13.4))),
                S(seg(19.4, 4.6, 12.4, 11.6), SD),
                S(seg(4.6, 19.4, 11.6, 12.4), SD)])
def_('compress', [S(P((12.4, 4.6), (12.4, 11.6), (19.4, 11.6))),
                  S(P((11.6, 19.4), (11.6, 12.4), (4.6, 12.4)))])
def_('sidebar', [S(rr(3.0, 4.4, 18.0, 15.2, 3.0)),
                 S(seg(9.2, 4.4, 9.2, 19.6), SD),
                 Of(rr(3.0, 4.4, 6.2, 15.2, 3.0))])
def_('split', [S(rr(3.0, 4.4, 18.0, 15.2, 3.0)),
               S(seg(12, 4.4, 12, 19.6)),
               Of(rr(3.0, 4.4, 9.0, 15.2, 3.0))])
def_('rule', [S(seg(4.0, 12, 20.0, 12))])
def_('window', [S(rr(3.0, 4.4, 18.0, 15.2, 3.2)),
                S(seg(3.0, 8.6, 21.0, 8.6), SD),
                S(circle(5.9, 6.5, 0.75), SD), S(circle(8.5, 6.5, 0.75), SD)])

# -- structure
def_('plus', [S(seg(12, 4.8, 12, 19.2)), S(seg(4.8, 12, 19.2, 12))])
def_('minus', [S(seg(4.8, 12, 19.2, 12))])
def_('close', [S(seg(6.0, 6.0, 18.0, 18.0)), S(seg(18.0, 6.0, 6.0, 18.0))])
def_('tab', [S(rr(3.2, 6.2, 17.6, 13.2, 2.8, 'tl')),
             S(seg(3.2, 10.4, 20.8, 10.4), SD),
             S(circle(6.6, 8.3, 0.8), SD)])
def_('tabs', [S(rr(2.8, 7.0, 13.0, 12.4, 2.6, 'tl')),
              S(P((7.0, 7.0), (7.0, 3.8), (21.0, 3.8), (21.0, 16.2)), SD)])
def_('grid', [S(rr(3.6, 3.6, 7.2, 7.2, 2.2)), S(rr(13.2, 3.6, 7.2, 7.2, 2.2)),
              S(rr(3.6, 13.2, 7.2, 7.2, 2.2)), S(rr(13.2, 13.2, 7.2, 7.2, 2.2))])
def_('list', [S(circle(5.0, 6.6, 1.05)), S(seg(8.4, 6.6, 20.2, 6.6)),
              S(circle(5.0, 12.0, 1.05)), S(seg(8.4, 12.0, 20.2, 12.0)),
              S(circle(5.0, 17.4, 1.05)), S(seg(8.4, 17.4, 20.2, 17.4))])
def_('text', [S(seg(5.6, 5.4, 18.4, 5.4)), S(seg(12, 5.4, 12, 18.6)),
              S(seg(8.8, 18.6, 15.2, 18.6), SD)])
def_('dial', [S(circle(12, 12, 8.4)), S(seg(12, 12, 15.4, 8.8)),
              S(circle(12, 12, 0.85), SD),
              S(seg(12, 3.6, 12, 5.2), SD), S(seg(20.4, 12, 18.8, 12), SD),
              S(seg(12, 20.4, 12, 18.8), SD), S(seg(3.6, 12, 5.2, 12), SD)])

# -- address bar, security, status
def_('search', magnifier())
def_('find', magnifier(hx=19.0, hy=19.0) +
      [S(seg(8.0, 10.6, 13.2, 10.6), SD)])
def_('lock', [S(rr(4.6, 10.2, 14.8, 9.6, 2.8)),
              S(P((7.9, 10.2), (7.9, 7.4), (12, 4.4), (16.1, 7.4), (16.1, 10.2))),
              S(circle(12, 14.2, 1.15), SD), S(seg(12, 15.3, 12, 16.9), SD)])
def_('globe', [S(circle(12, 12, 8.4)), S(ellipse(12, 12, 3.5, 8.4), SD),
               S(seg(3.6, 12, 20.4, 12), SD),
               S(arc(12, 12, 8.4, 200, 340, 40), SD),
               S(arc(12, 12, 8.4, -20, 160, 40), SD)])
def_('shield', [S(shield())])
def_('shield-on', [Of(shield()), S(shield()),
                   S(P((8.9, 11.6), (11.3, 14.1), (15.6, 9.2)), SD)])
def_('shield-off', [S(shield()), S(seg(5.0, 19.4, 19.0, 5.4))])
def_('star', [S(star(12, 12.6, 8.6, 3.8))])
def_('star-on', [Of(star(12, 12.6, 8.6, 3.8)), S(star(12, 12.6, 8.6, 3.8))])
def_('bookmark', [S(P((6.4, 20.4), (6.4, 4.6), (17.6, 4.6), (17.6, 20.4),
                      (12, 15.6)))])
def_('bookmarks', [S(P((8.0, 20.4), (8.0, 6.2), (19.0, 6.2), (19.0, 20.4),
                       (13.5, 16.0))),
                   S(P((4.8, 17.8), (4.8, 3.6), (15.6, 3.6)), SD)])
def_('private', [S(P((7.0, 12.2), (7.0, 6.8), (12, 4.4), (17.0, 6.8),
                     (17.0, 12.2))),
                 S(arc(12.0, 11.0, 8.8, 22, 158, 40)),
                 S(seg(7.0, 9.6, 17.0, 9.6), SD)])
def_('eye', [S(join(arc(12, 17.0, 8.4, 214, 326, 40),
                    arc(12, 7.0, 8.4, 34, 146, 40))),
             S(circle(12, 12, 2.9), SD)])
def_('eye-off', [S(join(arc(12, 17.0, 8.4, 214, 268, 40),
                        arc(12, 7.0, 8.4, 100, 146, 40))),
                 S(arc(12, 7.0, 8.4, 34, 60, 40)),
                 S(arc(12, 17.0, 8.4, 292, 326, 40)),
                 S(seg(4.8, 19.2, 19.2, 4.8))])
def_('key', [S(circle(7.4, 16.0, 3.9)), S(seg(10.2, 13.2, 19.6, 3.8)),
             S(seg(15.6, 7.8, 17.8, 10.0), SD), S(seg(13.0, 10.4, 15.0, 12.4), SD)])
def_('block', [S(circle(12, 12, 8.2)), S(seg(6.4, 6.4, 17.6, 17.6))])
def_('alert', [S(poly([(12, 3.0), (21.4, 19.9), (2.6, 19.9)])),
               S(seg(12, 8.8, 12, 14.0)), S(circle(12, 16.9, 0.95), SD)])
def_('info', [S(circle(12, 12, 8.4)), S(seg(12, 11.0, 12, 16.6)),
              S(circle(12, 7.9, 0.95), SD)])
def_('check', [S(P((4.8, 12.8), (9.7, 17.6), (19.4, 6.4)))])
def_('check-circle', [S(circle(12, 12, 8.4)),
                      S(P((8.2, 12.2), (11.0, 15.0), (15.9, 9.0)), SD)])
def_('x-circle', [S(circle(12, 12, 8.4)), S(seg(9.1, 9.1, 14.9, 14.9), SD),
                  S(seg(14.9, 9.1, 9.1, 14.9), SD)])
def_('circle', [S(circle(12, 12, 7.2))])
def_('dot', [S(circle(12, 12, 2.9)), S(circle(12, 12, 7.4), SD)])
def_('cookie', [S(circle(12, 12, 8.4)), S(circle(9.4, 9.2, 0.95), SD),
                S(circle(14.8, 10.8, 0.95), SD), S(circle(10.2, 14.8, 0.95), SD),
                S(circle(15.6, 15.4, 0.85), SD)])

# -- actions
def_('download', [S(seg(12, 3.8, 12, 14.2)), S(head(12, 14.2, 'down', 3.5)),
                  S(P((4.4, 16.4), (4.4, 20.0), (19.6, 20.0), (19.6, 16.4)))])
def_('save', [S(rr(4.2, 4.2, 15.6, 15.6, 3.0, 'br')),
              S(P((8.4, 4.2), (8.4, 9.6), (15.2, 9.6), (15.2, 4.2)), SD),
              S(rr(8.2, 13.0, 7.6, 6.8, 1.6), SD)])
BOOK = ('M 4.4 6.4 C 7.0 5.0 10.2 5.6 12 7.0 C 13.8 5.6 17.0 5.0 19.6 6.4 '
        'L 19.6 17.4 C 17.0 16.0 13.8 16.6 12 18.0 C 10.2 16.6 7.0 16.0 '
        '4.4 17.4 Z')
def_('reader', [S(BOOK), S(seg(12, 7.0, 12, 18.0), SD),
                S(seg(6.6, 9.6, 9.6, 10.4), SD),
                S(seg(6.6, 12.6, 9.6, 13.4), SD),
                S(seg(14.4, 10.4, 17.4, 9.6), SD)])
def_('reading-list', [S(rr(4.6, 3.4, 14.8, 17.2, 3.0, 'tr')),
                      S(seg(8.0, 8.2, 14.4, 8.2), SD),
                      S(seg(8.0, 12.0, 16.2, 12.0), SD),
                      S(seg(8.0, 15.8, 12.6, 15.8), SD)])
def_('external', [S(P((13.2, 4.6), (19.4, 4.6), (19.4, 10.8))),
                  S(seg(19.4, 4.6, 11.0, 13.0)),
                  S(P((14.6, 8.6), (5.0, 8.6), (5.0, 19.4), (15.8, 19.4),
                      (15.8, 12.4)))])
def_('print', [S(P((7.4, 8.8), (7.4, 4.0), (16.6, 4.0), (16.6, 8.8))),
               S(rr(3.8, 8.8, 16.4, 6.6, 2.2)),
               S(P((7.4, 13.2), (7.4, 20.0), (16.6, 20.0), (16.6, 13.2)), SD),
               S(circle(17.0, 11.8, 0.8), SD)])
def_('share', [S(circle(17.4, 5.8, 2.5)), S(circle(6.6, 12, 2.5)),
               S(circle(17.4, 18.2, 2.5)),
               S(seg(8.8, 10.9, 15.2, 7.0)), S(seg(8.8, 13.1, 15.2, 17.0))])
def_('pin', [S(P((8.8, 3.4), (15.2, 3.4), (13.6, 9.4), (16.8, 12.0),
                 (7.2, 12.0), (10.4, 9.4))),
             S(seg(12, 12.6, 12, 20.4))])
def_('bolt', [S(P((13.8, 2.6), (6.2, 13.4), (11.2, 13.4), (10.0, 21.4),
                  (17.8, 10.0), (12.8, 10.0)))])
def_('flame', [S(join(arc(12, 14.0, 6.6, 0, 180, 40),
                     P((5.4, 14.0), (9.2, 10.2), (9.8, 5.4), (12, 2.8),
                       (15.0, 6.6), (17.0, 8.6), (18.6, 14.0)))),
               S(arc(12, 15.0, 2.9, 20, 160, 40), SD)])
def_('sparkle', [S(P((11.4, 2.8), (12.9, 8.0), (18.2, 9.6), (12.9, 11.2),
                     (11.4, 16.4), (9.9, 11.2), (4.6, 9.6), (9.9, 8.0))),
                 S(P((18.0, 15.0), (18.8, 17.4), (21.2, 18.2), (18.8, 19.0),
                     (18.0, 21.4), (17.2, 19.0), (14.8, 18.2), (17.2, 17.4)),
                   SD)])
def_('clock', [S(circle(12, 12, 8.4)), S(seg(12, 7.2, 12, 12.4)),
               S(seg(12, 12.4, 15.6, 14.4))])
def_('history', [S(arc(12, 12, 8.2, 128, 402, 40)),
                 S(P((3.4, 9.0), (2.9, 14.2), (8.0, 14.9))),
                 S(seg(12, 7.6, 12, 12.2), SD), S(seg(12, 12.2, 15.2, 13.9), SD)])

# -- editing
def_('pencil', [S(P((4.2, 19.8), (5.0, 16.2), (15.4, 5.8), (19.0, 9.4),
                    (8.6, 19.8))),
                S(seg(13.4, 7.8, 17.0, 11.4), SD),
                S(seg(5.0, 16.2, 8.6, 19.8), SD)])
def_('copy', [S(rr(8.6, 8.6, 11.6, 11.6, 2.8, 'tr')),
              S(P((15.2, 5.6), (15.2, 4.0), (4.0, 4.0), (4.0, 15.2),
                  (5.6, 15.2)))])
def_('cut', [S(circle(6.6, 17.2, 2.7)), S(circle(6.6, 6.8, 2.7)),
             S(seg(8.7, 8.6, 19.6, 17.4)), S(seg(8.7, 15.4, 19.6, 6.6))])
def_('paste', [S(rr(4.4, 5.0, 15.2, 15.2, 2.8)),
               S(rr(8.8, 2.8, 6.4, 3.8, 1.6), SD),
               S(seg(7.6, 10.8, 16.4, 10.8), SD),
               S(seg(7.6, 14.0, 13.4, 14.0), SD)])
def_('trash', [S(seg(4.8, 6.8, 19.2, 6.8)),
               S(P((6.8, 6.8), (7.7, 20.2), (16.3, 20.2), (17.2, 6.8))),
               S(P((9.8, 4.2), (9.8, 6.8), (14.2, 6.8), (14.2, 4.2)), SD),
               S(seg(10.3, 10.4, 10.7, 17.0), SD),
               S(seg(13.7, 10.4, 13.3, 17.0), SD)])
def_('clear', [S(rr(3.4, 8.6, 12.6, 6.8, 3.4)),
               S(P((16.0, 8.6), (20.6, 12.0), (16.0, 15.4))),
               S(seg(6.6, 12.0, 11.4, 12.0), SD)])
def_('move', [S(seg(12, 3.4, 12, 20.6)), S(seg(3.4, 12, 20.6, 12)),
              S(head(12, 3.4, 'up', 2.7), SD), S(head(12, 20.6, 'down', 2.7), SD),
              S(head(3.4, 12, 'left', 2.7), SD),
              S(head(20.6, 12, 'right', 2.7), SD)])
def_('sort', [S(seg(6.4, 4.4, 6.4, 19.6)), S(head(6.4, 19.6, 'down', 3.0)),
              S(seg(11.6, 6.8, 19.8, 6.8)), S(seg(11.6, 11.6, 17.6, 11.6)),
              S(seg(11.6, 16.4, 15.4, 16.4))])
def_('filter', [S(P((3.6, 5.2), (20.4, 5.2), (13.2, 12.4), (13.2, 19.6),
                    (10.8, 17.2), (10.8, 12.4)))])

# -- files
def_('folder', [S(folder())])
def_('folder-on', [Of(folder()), S(folder())])
def_('folder-open', [S(P((2.6, 6.0), (9.0, 6.0), (11.2, 8.6), (21.4, 8.6),
                         (21.4, 11.2))),
                     S(P((2.6, 19.0), (21.4, 19.0), (19.2, 11.2), (2.6, 11.2)))])
def_('folder-plus', [S(P((2.6, 6.0), (8.6, 6.0), (10.8, 8.6), (21.4, 8.6),
                         (21.4, 19.0), (2.6, 19.0))),
                      S(seg(12, 11.6, 12, 16.4), SD),
                      S(seg(9.6, 14.0, 14.4, 14.0), SD)])
def_('folder-block', [S(P((2.6, 6.0), (8.6, 6.0), (10.8, 8.6), (21.4, 8.6),
                           (21.4, 19.0), (2.6, 19.0))),
                      S(seg(9.6, 11.8, 14.4, 16.2), SD),
                      S(seg(14.4, 11.8, 9.6, 16.2), SD)])
def_('drive', [S(rr(2.8, 12.4, 18.4, 7.2, 2.6)),
               S(P((4.4, 12.4), (6.2, 5.6), (17.8, 5.6), (19.6, 12.4))),
               S(circle(17.2, 16.0, 1.05), SD), S(seg(6.4, 16.0, 11.2, 16.0), SD)])
def_('file', [S(page()), S(fold(), SD)])
def_('file-text', [S(page()), S(fold(), SD), S(seg(7.6, 11.4, 16.4, 11.4), SD),
                   S(seg(7.6, 14.4, 16.4, 14.4), SD),
                   S(seg(7.6, 17.4, 12.6, 17.4), SD)])
def_('file-code', [S(page()), S(fold(), SD),
                   S(P((9.4, 11.4), (7.6, 14.2), (9.4, 17.0)), SD),
                   S(P((14.6, 11.4), (16.4, 14.2), (14.6, 17.0)), SD),
                   S(seg(12.2, 10.8, 11.0, 18.0), SD)])
def_('code', [S(P((8.6, 6.0), (3.4, 12), (8.6, 18))),
              S(P((15.4, 6.0), (20.6, 12), (15.4, 18))),
              S(seg(13.4, 4.2, 10.6, 19.8), SD)])
def_('file-image', [S(page()), S(fold(), SD), S(circle(8.6, 11.4, 1.25), SD),
                    S(P((6.4, 17.6), (9.8, 14.0), (12.2, 16.2), (14.2, 14.2),
                        (17.6, 17.6)), SD)])
def_('image', [S(rr(3.2, 4.4, 17.6, 15.2, 3.0, 'tr')),
               S(circle(8.2, 8.8, 1.6), SD),
               S(P((4.4, 17.2), (9.4, 11.8), (12.8, 15.2), (15.2, 12.6),
                   (19.8, 17.6), (20.6, 18.6)), SD)])
def_('images', [S(rr(6.0, 3.4, 14.6, 12.8, 2.8, 'tr')),
                S(P((18.4, 20.6), (3.4, 20.6), (3.4, 8.2)), SD),
                S(circle(10.0, 7.0, 1.2), SD),
                S(P((7.2, 13.4), (10.6, 9.8), (13.4, 12.4), (15.4, 10.4),
                    (18.0, 13.0)), SD)])
def_('file-video', [S(page()), S(fold(), SD),
                    S(P((9.6, 11.4), (14.6, 14.2), (9.6, 17.0)), SD)])
def_('video', [S(rr(2.8, 5.2, 18.4, 13.6, 3.0, 'tr')),
               S(P((10.2, 9.0), (14.8, 12.0), (10.2, 15.0)))])
def_('music', [S(circle(6.6, 17.4, 2.5)), S(seg(9.1, 17.4, 9.1, 5.6)),
               S(P((9.1, 5.6), (18.2, 4.0), (18.2, 15.2))),
               S(circle(15.7, 15.2, 2.5)), S(seg(9.1, 8.4, 18.2, 6.8), SD)])
def_('file-audio', [S(page()), S(fold(), SD), S(seg(13.8, 17.2, 13.8, 11.0), SD),
                    S(circle(12.0, 17.4, 1.8), SD),
                    S(P((13.8, 11.0), (16.8, 10.2), (16.8, 12.8)), SD)])
ZIP = rr(4.4, 3.2, 15.2, 17.6, 3.0, 'tr')
def_('archive', [S(ZIP),
                 S(seg(4.4, 8.4, 19.6, 8.4), SD),
                 S(rr(10.6, 5.2, 2.8, 3.2, 0.9), SD),
                 S(seg(8.6, 12.4, 8.6, 14.4), SD),
                 S(seg(15.4, 12.4, 15.4, 14.4), SD),
                 S(seg(8.6, 12.4, 15.4, 12.4), SD)])

def_('file-pdf', [S(page()), S(fold(), SD), S(seg(7.4, 12.6, 16.6, 12.6), SD),
                  S(seg(7.4, 15.6, 13.0, 15.6), SD),
                  S(P((14.0, 10.0), (16.8, 10.0), (16.8, 12.0)), SD)])
D['zip'] = D['archive']
D['file-zip'] = [S(page()), S(fold(), SD),
                 S(seg(7.6, 10.6, 16.4, 10.6), SD),
                 S(P((10.6, 12.8), (13.4, 12.8), (13.4, 15.0), (10.6, 15.0),
                     (10.6, 17.2), (13.4, 17.2)), SD)]
D['pdf'] = D['file-pdf']

# -- look, devices
def_('sliders', [S(seg(3.8, 8.0, 20.2, 8.0)), S(seg(3.8, 16.0, 20.2, 16.0)),
                 S(rr(7.0, 5.6, 3.0, 4.8, 1.4), SD),
                 S(rr(13.6, 13.6, 3.0, 4.8, 1.4), SD)])
def_('sun', [S(circle(12, 12, 4.1))] +
       [S(seg(12 + 6.8 * math.cos(math.radians(a)),
              12 + 6.8 * math.sin(math.radians(a)),
              12 + 9.3 * math.cos(math.radians(a)),
              12 + 9.3 * math.sin(math.radians(a))), SD)
        for a in range(0, 360, 45)])
def_('moon', [S(join(arc(11.4, 12, 8.4, 66.8, 293.2, 40),
                     arc(16.8, 12, 7.8, 256.0, 104.0, 40)))])
def_('auto', [S(circle(12.4, 12.4, 6.2)),
              Fl(join(arc(12.4, 12.4, 6.2, 90, 270, 40),
                      P((12.4, 6.2), (12.4, 18.6)))),
              S(seg(12.4, 5.0, 12.4, 3.0), SD),
              S(seg(19.8, 12.4, 21.6, 12.4), SD),
              S(seg(17.6, 7.2, 19.0, 5.8), SD)])
def_('contrast', [S(circle(12, 12, 8.4)),
                  Fl(join(arc(12, 12, 8.4, -90, 90, 40),
                          P((12, 20.4), (12, 3.6))))])
def_('palette', [S(rr(3.4, 3.4, 17.2, 17.2, 3.2, 'tr')),
                 Fl(rr(6.4, 6.4, 5.0, 5.0, 1.6)),
                 S(circle(15.6, 8.9, 1.35), SD),
                 S(circle(8.9, 15.6, 1.35), SD),
                 S(circle(15.6, 15.6, 1.35), SD)])
def_('keyboard', [S(rr(2.6, 6.2, 18.8, 11.6, 2.8)),
                  S(circle(6.2, 9.8, 0.7), SD), S(circle(9.4, 9.8, 0.7), SD),
                  S(circle(12.6, 9.8, 0.7), SD), S(circle(15.8, 9.8, 0.7), SD),
                  S(circle(18.6, 9.8, 0.7), SD),
                  S(seg(7.8, 14.0, 16.2, 14.0), SD)])
def_('monitor', [S(rr(2.8, 4.2, 18.4, 12.6, 2.8)), S(seg(12, 16.8, 12, 20.0)),
                 S(seg(8.2, 20.0, 15.8, 20.0))])
def_('device', [S(rr(6.6, 2.6, 10.8, 18.8, 2.8, 'tr')),
                S(seg(9.8, 17.8, 14.2, 17.8), SD)])
def_('camera', [S(rr(2.8, 6.4, 18.4, 12.8, 3.0)),
                S(P((8.4, 6.4), (9.8, 3.8), (14.2, 3.8), (15.6, 6.4))),
                S(circle(12, 12.8, 3.4), SD), S(circle(18.0, 9.4, 0.7), SD)])
def_('mic', [S(rr(9.0, 2.6, 6.0, 10.8, 3.0)), S(arc(12, 12.2, 6.6, 22, 158, 40)),
             S(seg(12, 18.8, 12, 21.2)), S(seg(8.8, 21.2, 15.2, 21.2), SD)])
def_('location', [S(join(arc(12, 9.8, 5.6, 18, 162, 40),
                         P((6.8, 11.4), (12, 20.6), (17.2, 11.4)))),
                  S(circle(12, 9.6, 2.1), SD)])
def_('wifi', [S(arc(12, 17.2, 10.6, 214, 326, 40)),
              S(arc(12, 17.2, 6.8, 214, 326, 40)),
              S(circle(12, 17.0, 1.25), SD)])
def_('wifi-off', [S(arc(12, 17.2, 10.6, 214, 268, 40)),
                  S(arc(12, 17.2, 10.6, 296, 326, 40)),
                  S(arc(12, 17.2, 6.8, 222, 244, 40)),
                  S(circle(12, 17.0, 1.25), SD), S(seg(4.4, 4.4, 19.6, 19.6))])
def_('leaf', [S(join(arc(6.8, 6.8, 13.0, 100.6, -10.6, 40),
                     arc(17.2, 17.2, 13.0, 280.6, 169.4, 40))),
              S(seg(6.6, 17.4, 17.4, 6.6), SD),
              S(seg(4.4, 19.6, 6.6, 17.4), SD)])
def_('wallpaper', [S(rr(3.2, 4.4, 17.6, 15.2, 3.0, 'tr')),
                   S(P((4.4, 17.0), (9.0, 11.8), (12.4, 15.0), (14.8, 12.6),
                       (19.8, 17.4)), SD),
                   S(circle(7.8, 8.4, 1.5), SD)])

# ------------------------------------------------------------------ emitting --
HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
        'viewBox="0 0 24 24" fill="none">')


def svg_for(shapes):
    parts = []
    for kind, d, w in shapes:
        d = ' '.join(d.split())
        if kind == 'f':
            parts.append(f'<path d="{d}" fill="#000"/>')
        elif kind == 'o':
            parts.append(f'<path d="{d}" fill="#000" fill-opacity=".18"/>')
        else:
            parts.append(f'<path d="{d}" fill="none" stroke="#000" '
                         f'stroke-width="{n(w)}" stroke-linecap="round" '
                         f'stroke-linejoin="round"/>')
    return HEAD + '\n' + '\n'.join(parts) + '\n</svg>\n'


def numbers(d):
    out = []
    for chunk in d.replace('M', ' ').replace('L', ' ').replace('C', ' ')\
                  .replace('Z', ' ').split():
        out.append(float(chunk))
    return out


def check():
    problems = []
    want = names()
    for name in want:
        if name not in D:
            problems.append(f'{name}: no drawing defined')
    for name in sorted(D):
        if name not in want:
            problems.append(f'{name}: defined but not shipped')
    for name, shapes in D.items():
        if not shapes:
            problems.append(f'{name}: empty')
            continue
        for kind, d, w in shapes:
            d = ' '.join(d.split())
            letters = set(c for c in d if c.isalpha())
            if letters - set('MLCZ'):
                problems.append(f'{name}: forbidden commands {sorted(letters)}')
            if not d.startswith('M '):
                problems.append(f'{name}: does not start with a move')
            nums = numbers(d)
            if len(nums) % 2:
                problems.append(f'{name}: odd number of coordinates')
            for v in nums:
                if not (EDGE[0] - 0.6 <= v <= EDGE[1] + 0.6):
                    problems.append(f'{name}: {v} outside the live area')
            if any(math.isnan(v) for v in nums):
                problems.append(f'{name}: NaN')
    return problems, want


def names():
    if not os.path.isdir(OUT):
        return sorted(D)
    return sorted(f[:-4] for f in os.listdir(OUT) if f.endswith('.svg'))


def emit():
    problems, _ = check()
    if problems:
        for p in problems:
            print('  ' + p)
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    for name, shapes in sorted(D.items()):
        with open(os.path.join(OUT, name + '.svg'), 'w') as f:
            f.write(svg_for(shapes))
    print(f'emitted {len(D)} icons')
    # Prove the output parses as SVG and keeps the house rules.
    bad = []
    for name in sorted(D):
        raw = open(os.path.join(OUT, name + '.svg')).read()
        try:
            root = ET.fromstring(raw)
        except ET.ParseError as e:
            bad.append(f'{name}: {e}')
            continue
        if root.get('viewBox') != '0 0 24 24':
            bad.append(f'{name}: bad viewBox')
        for path in root.iter('{http://www.w3.org/2000/svg}path'):
            if 'A' in (path.get('d') or ''):
                bad.append(f'{name}: arc command')
    if bad:
        for b in bad:
            print('  ' + b)
        sys.exit(1)
    print('all files parse; viewBox and weights are consistent')


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else '--qa'
    if mode == '--emit':
        emit()
    elif mode == '--sheet':
        print(f'{len(D)} icons\n' + ' '.join(sorted(D)))
    elif mode == '--missing':
        want = names()
        print('unhandled: ' + ', '.join(x for x in want if x not in D))
    else:
        problems, want = check()
        for p in problems:
            print('  ' + p)
        if problems:
            sys.exit(1)
        print(f'ok - {len(D)} drawings for {len(want)} shipped icons')


if __name__ == '__main__':
    main()
