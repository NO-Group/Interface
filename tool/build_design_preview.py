#!/usr/bin/env python3
"""Builds design/index.html: the styling sheet the app is made of.

The page is generated, so it can never drift from the app: the colours are
read out of lib/core/palette.dart and the icons are inlined from
assets/icons/. Open it in a browser, or:

    python3 tool/build_design_preview.py && python3 -m http.server -d design 8090
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, 'assets', 'icons')
OUT = os.path.join(ROOT, 'design', 'index.html')

# ------------------------------------------------------------------ colours --
PAL = os.path.join(ROOT, 'lib', 'core', 'palette.dart')


def read_palette():
    src = open(PAL).read()
    named = {}
    for m in re.finditer(r'static const Color (\w+) = Color\(0x([0-9A-Fa-f]{8})\)', src):
        named[m.group(1)] = '#' + m.group(2)[2:]
    out = {}
    for theme in ('light', 'dark'):
        blk = re.search(r'static const %s = BrowserPalette\((.*?)\n  \);' % theme,
                        src, re.S)
        if not blk:
            continue
        vals = {}
        for m in re.finditer(r'(\w+):\s*(?:const\s+)?Color\(0x([0-9A-Fa-f]{8})\)|(\w+):\s*(\w+),',
                             blk.group(1)):
            key = m.group(1) or m.group(3)
            if m.group(2):
                vals[key] = '#' + m.group(2)[2:]
            elif m.group(4) in named:
                vals[key] = named[m.group(4)]
        out[theme] = vals
    if 'light' not in out or 'dark' not in out:
        raise SystemExit('could not read the palette out of palette.dart')
    return out


PAL_COLORS = read_palette()

FIELD_DEFAULTS = {
    'background': '#0B1220', 'surface': '#111A2C', 'surfaceAlt': '#16223A',
    'omniboxFill': '#0E1626', 'chromeFill': '#0D1524', 'text': '#E8F0FA',
    'textDim': '#93A6C0', 'primary': '#14336B', 'onPrimary': '#EAF6FF',
    'accent': '#22D3EE', 'onAccent': '#04222B', 'border': '#25374F',
}


def pal(theme, key):
    v = PAL_COLORS[theme].get(key)
    if v:
        return v
    other = 'light' if theme == 'dark' else 'dark'
    v = PAL_COLORS[other].get(key)
    return v or FIELD_DEFAULTS.get(key, '#888888')


def rgba(hexv, a):
    h = hexv.lstrip('#')
    o = 2 if len(h) == 8 else 0   # the Dart 0xAARRGGBB form leads with alpha
    r, g, b = int(h[o:o + 2], 16), int(h[o + 2:o + 4], 16), int(h[o + 4:o + 6], 16)
    return f'rgba({r}, {g}, {b}, {a})'


def icon(name, size=20, color='#000000'):
    path = os.path.join(ICONS, name + '.svg')
    if not os.path.exists(path):
        return ''
    s = open(path).read()
    s = re.sub(r'^<svg[^>]*>', '', s)
    s = s.replace('</svg>', '').strip()
    s = s.replace('#000', color)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" '
            f'height="{size}" viewBox="0 0 24 24" fill="none" '
            f'aria-hidden="true">{s}</svg>')


# ------------------------------------------------------------------------ css
CSS = """
:root{
  --bg:__BG__; --surface:__SURF__; --surface-alt:__SURFALT__; --field:__FIELD__;
  --chrome:__CHROME__; --text:__TEXT__; --dim:__DIM__; --faint:__FAINT__;
  --border:__BORDER__; --accent:__ACCENT__; --primary:__PRIMARY__;
  --on-primary:__ONPRIM__; --lit:rgba(255,255,255,.10); --hair:rgba(255,255,255,.06);
  --r-control:9px 9px 3px 9px;
  --r-field:11px 11px 3.5px 11px;
  --r-card:15px 15px 4.5px 15px;
  --r-menu:4px 13px 13px 13px;
  --r-sheet:19px 19px 0 0;
  --r-tab:11px 11px 3.5px 11px;
}
:root[data-theme=light]{
  --lit:rgba(255,255,255,.85); --hair:rgba(11,22,40,.10);
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
  font:400 14px/1.45 ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
  letter-spacing:.08px;padding:0 0 90px}
h1,h2,h3{margin:0;font-weight:700;letter-spacing:0}
h1{font-size:30px;line-height:1.2}
h2{font-size:21px;margin:0 0 4px}
h3{font-size:15.5px}
p{margin:6px 0 0;color:var(--dim);max-width:70ch}
.wrap{max-width:1180px;margin:0 auto;padding:0 28px}
section{margin-top:46px}
.lede{padding:44px 0 8px}
.kicker{font-size:12px;letter-spacing:.14em;text-transform:lowercase;color:var(--accent)}
.row{display:flex;gap:14px;flex-wrap:wrap;align-items:flex-start}
.grid{display:grid;gap:14px}
.note{font-size:12.5px;color:var(--faint);max-width:44ch}
.surface,.plate{background:var(--surface);border:1px solid var(--border);
  border-radius:var(--r-card);
  background-image:linear-gradient(to bottom,var(--lit) 0 2px,transparent 2px)}
.plate{padding:16px}
.spec{flex:1 1 150px;min-width:140px}
.spec .cap{margin-top:8px;font-size:12px;color:var(--faint)}
.sw{display:flex;align-items:center;gap:10px;padding:12px 14px}
.btn{display:inline-flex;align-items:center;gap:8px;padding:10px 16px;
  border-radius:var(--r-control);border:1px solid transparent;
  background:var(--primary);color:var(--on-primary);font-weight:600;font-size:13px;
  cursor:default}
.btn.ghost{background:transparent;border-color:var(--border);color:var(--text)}
.chip{display:inline-flex;align-items:center;gap:7px;padding:6px 11px;
  border-radius:var(--r-control);border:1px solid rgba(34,211,238,.45);
  background:rgba(34,211,238,.14);font-size:12.5px;font-weight:600}
.field{display:flex;align-items:center;gap:10px;padding:11px 14px;
  background:var(--field);border:1px solid var(--border);
  border-radius:var(--r-field);color:var(--dim);font-size:13.5px}
.field.focus{background:var(--surface);border-color:var(--accent);border-width:1.4px;
  color:var(--text);
  box-shadow:0 0 16px .5px rgba(34,211,238,.26)}
.menu{background:var(--surface);border:1px solid var(--border);
  border-radius:var(--r-menu);padding:6px;min-width:210px;
  background-image:linear-gradient(to bottom,var(--lit) 0 2px,transparent 2px);
  box-shadow:0 10px 26px rgba(0,0,0,.55)}
.menu .it{display:flex;align-items:center;gap:10px;padding:9px 10px;
  border-radius:var(--r-control);font-size:13px}
.menu .it.on{background:rgba(34,211,238,.16)}
.chrome{background:var(--chrome);border-top:1px solid var(--lit);
  border-bottom:1px solid var(--border);padding:0 10px}
.chrome .row{align-items:center;gap:8px;padding:9px 0;min-height:52px}
.ib{width:34px;height:34px;display:grid;place-items:center;border-radius:var(--r-control);
  color:var(--dim)}
.ib.hot{background:var(--surface-alt);color:var(--text)}
.tabs{display:flex;gap:6px;align-items:center;flex:0 1 auto}
.tab{display:flex;align-items:center;gap:8px;height:34px;padding:0 9px 0 11px;
  border-radius:var(--r-tab);border:1px solid transparent;color:var(--dim);
  font-size:12.5px;max-width:210px}
.tab.on{background:var(--surface);border-color:var(--border);color:var(--text);
  box-shadow:0 0 16px .5px rgba(34,211,238,.14);
  background-image:linear-gradient(to bottom,var(--lit) 0 1px,transparent 1px)}
.tab .t{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.addr{flex:1 1 320px;max-width:660px;display:flex;align-items:center;gap:9px;
  height:36px;padding:0 12px;background:var(--field);border:1px solid var(--border);
  border-radius:var(--r-field);font-size:13px;color:var(--text)}
.prog{height:2px;background:linear-gradient(90deg,transparent,rgba(34,211,238,.14) 12%,rgba(34,211,238,.14) 88%,transparent)}
.prog i{display:block;height:2px;width:46%;border-radius:0 2px 2px 0;
  background:var(--accent);box-shadow:0 0 7px rgba(34,211,238,.65)}
.home{padding:52px 24px 44px;text-align:center;position:relative;overflow:hidden}
.home:before{content:"";position:absolute;inset:-40% 0 auto 0;height:120%;
  background:radial-gradient(60% 62% at 50% 0%,rgba(34,211,238,.11),transparent 70%)}
.home>*{position:relative}
.greet{font-size:15.5px;color:var(--dim)}
.search{max-width:660px;margin:22px auto 0;text-align:left}
.dials{display:flex;gap:14px;justify-content:center;flex-wrap:wrap;margin-top:26px}
.dial{width:92px}
.dial .cap{margin-top:7px;font-size:12.5px;white-space:nowrap;overflow:hidden;
  text-overflow:ellipsis}
.tile{width:62px;height:62px;display:grid;place-items:center;background:var(--surface);
  border:1px solid var(--border);border-radius:var(--r-card);color:var(--accent);
  background-image:linear-gradient(to bottom,var(--lit) 0 2px,transparent 2px)}
.list{background:var(--surface);border:1px solid var(--border);
  border-radius:var(--r-card);padding:6px;
  background-image:linear-gradient(to bottom,var(--lit) 0 2px,transparent 2px)}
.list .it{display:flex;align-items:center;gap:11px;padding:9px 10px;
  border-radius:var(--r-control);min-height:44px}
.list .it.on{background:rgba(34,211,238,.14);
  box-shadow:inset 2.6px 0 0 var(--accent)}
.list .it .n{flex:1;font-size:13px;white-space:nowrap;overflow:hidden;
  text-overflow:ellipsis}
.list .it .m{font-size:12px;color:var(--faint);white-space:nowrap}
.bar{display:flex;align-items:center;gap:8px;padding:9px 10px;min-height:46px;
  background:var(--chrome);border-bottom:1px solid var(--border);
  border-top:1px solid var(--lit);
  border-radius:var(--r-sheet);border-left:0;border-right:0;border-bottom:1px solid var(--border)}
.bar .crumbs{display:flex;align-items:center;gap:6px;flex:1;font-size:12.5px;
  color:var(--dim);white-space:nowrap;overflow:hidden}
.bar .crumbs b{color:var(--text);font-weight:600}
.selbar{display:flex;align-items:center;gap:8px;padding:8px 10px;min-height:44px;
  background:rgba(34,211,238,.10);border:1px solid rgba(34,211,238,.28);
  border-radius:var(--r-field);font-size:12.5px}
.welcome{padding:44px 24px 30px;text-align:center;position:relative;overflow:hidden;
  border-radius:var(--r-card);border:1px solid var(--border);background:var(--surface)}
.welcome:before{content:"";position:absolute;inset:-30% 0 auto 0;height:110%;
  background:radial-gradient(55% 60% at 50% 0%,rgba(34,211,238,.13),transparent 72%)}
.welcome>*{position:relative}
.mark{width:64px;height:64px;display:grid;place-items:center;margin:0 auto 26px;
  border-radius:20px 20px 6px 20px;border:1px solid rgba(34,211,238,.45);
  background:rgba(34,211,238,.14);color:var(--accent)}
.stitch{display:flex;gap:6px;justify-content:center;margin:24px 0 0}
.stitch i{width:10px;height:4px;border-radius:3px;background:var(--border)}
.stitch i.on{width:26px;background:var(--accent);box-shadow:0 0 8px rgba(34,211,238,.6)}
.types{display:grid;gap:12px}
.types div{border-bottom:1px solid var(--hair);padding-bottom:10px}
.legend{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
.legend span{font-size:12px;color:var(--faint);border:1px solid var(--border);
  border-radius:var(--r-control);padding:4px 9px}
.icons{display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:10px}
.ic{display:flex;flex-direction:column;align-items:center;gap:8px;padding:14px 6px 10px;
  border:1px solid transparent;border-radius:var(--r-control);color:var(--text)}
.ic:hover{background:var(--surface);border-color:var(--border)}
.ic span{font-size:11px;color:var(--faint);letter-spacing:.02em;text-align:center}
.themes{display:flex;gap:10px;align-items:center}
button.pill{appearance:none;border:1px solid var(--border);background:transparent;
  color:var(--text);font:inherit;font-size:12.5px;padding:7px 13px;cursor:pointer;
  border-radius:var(--r-control);display:inline-flex;align-items:center;gap:8px}
button.pill[aria-pressed=true]{border-color:var(--accent);
  background:rgba(34,211,238,.14);color:var(--text)}
.split{display:grid;grid-template-columns:1fr 1fr;gap:14px}
@media (max-width:760px){.split{grid-template-columns:1fr}}
.before{background:var(--surface);border:1px solid var(--border);border-radius:15px;
  padding:16px;color:var(--dim)}
.after{background:var(--surface);border:1px solid var(--border);
  border-radius:var(--r-card);padding:16px;color:var(--text);
  background-image:linear-gradient(to bottom,var(--lit) 0 2px,transparent 2px);
  box-shadow:0 0 0 1px rgba(34,211,238,.10)}
.tag{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--faint)}
hr{border:0;border-top:1px solid var(--border);margin:46px 0 0}
a{color:var(--accent)}
.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px}
"""


def body():
    d = 'dark'
    P = lambda k: pal(d, k)  # noqa: E731  (specimen colours; the CSS swaps them)
    acc = P('accent')
    ink = '#0B1626'

    def ic(name, size=20, color=None):
        return icon(name, size, color or 'currentColor')

    chrome_acts = ['shield-on', 'star', 'reader', 'download', 'split', 'sidebar',
                   'private', 'dots']
    tiles = [('folder', 'Documents'), ('image', 'Photos'), ('video', 'Movies'),
             ('music', 'Music'), ('archive', 'Backups'), ('file-text', 'Notes'),
             ('code', 'Projects'), ('download', 'Downloads')]
    files = [('folder', 'Projects', 'now'), ('folder-on', 'Interface', '2 h'),
             ('file-code', 'main.dart', '6 kb'), ('file-text', 'notes.md', '2 kb'),
             ('file-image', 'cover.png', '1.4 MB'), ('file-zip', 'bundle.zip', '9 MB')]
    icon_names = sorted(f[:-4] for f in os.listdir(ICONS) if f.endswith('.svg'))

    h = []
    h.append('<div class="wrap">')
    # ---- header
    h.append(f"""
<header class="lede">
  <div class="kicker">styling · v2.0.0</div>
  <h1>The chamfer</h1>
  <p>Every surface keeps three soft corners and one tight corner, and the tight
  one points at whatever the surface belongs to: a field's faces the page below
  it, a menu's points back at the button it dropped from, a row's faces the
  content it opens. Navy plate, one hairline weight, and colour only where
  something is actually happening — focus, loading, selected, blocked.</p>
  <div class="themes" style="margin-top:18px">
    <button class="pill" id="dark" aria-pressed="true">{ic('moon')} Dark</button>
    <button class="pill" id="light" aria-pressed="false">{ic('sun')} Light</button>
    <span class="note" style="margin-left:6px">Both themes are the app's own
      surfaces; nothing here borrows a control from another browser.</span>
  </div>
</header>""")

    # ---- corner specimens
    specs = [
        ('Control', 'rControl 9 · tight 3', 'buttons, chips, rows, icon wells'),
        ('Field', 'rField 11 · tight 3.5', 'the address bar, every input'),
        ('Card', 'rCard 15 · tight 4.5', 'tiles, panels, dialogs'),
        ('Menu', 'rMenu 13 · tight 4 up left', 'popovers point back at the bar'),
        ('Sheet', 'rSheet 19 · square below', 'docked sheets touch the edge'),
    ]
    h.append('<section><h2>One corner language</h2>'
             '<p>The same four numbers, everywhere. Nothing in the window '
             'invents its own radius.</p><div class="row" style="margin-top:14px">')
    for i, (name, cap, note) in enumerate(specs):
        cls = ['field', 'field focus', 'plate', 'menu', 'plate'][i]
        style = 'border-radius:var(--r-sheet);border-bottom:0' if name == 'Sheet' else ''
        h.append(f"""<div class="spec"><div class="{cls}" style="{style}">
          <div class="sw"><span style="color:var(--accent)">{ic(['plus', 'search', 'grid', 'menu', 'sidebar'][i])}</span>
          <span>{name}</span></div></div>
          <div class="cap mono">{cap}</div><div class="cap">{note}</div></div>""")
    h.append('</div></section>')

    # ---- lit edge / bloom
    h.append(f"""<section><h2>A lit edge and a bloom</h2>
    <p>Flat fill reads as a coloured rectangle. The first two pixels of every
    raised surface catch the light, and a field that has focus gets an accent
    keyline plus a soft halo — the only place accent appears on an idle screen.</p>
    <div class="split" style="margin-top:14px">
      <div><div class="tag">before</div><div class="before">
        <div class="field" style="margin-top:10px">
          <span style="color:var(--accent)">{ic('search')}</span>
          <span>Search or type an address</span></div>
        <div class="before" style="margin-top:10px;padding:14px">
          A surface with no edge: the boundary is a line of one grey.</div>
      </div></div>
      <div><div class="tag">now</div><div class="after">
        <div class="field focus" style="margin-top:10px">
          <span style="color:var(--accent)">{ic('search')}</span>
          <span>interface</span><span style="margin-left:auto;color:var(--accent)">{ic('chevron-down')}</span></div>
        <div class="after" style="margin-top:10px;padding:14px">
          The lit top edge and a 1.4px accent keyline with a 16px bloom.</div>
      </div></div>
    </div></section>""")

    # ---- chrome
    h.append(f"""<section><h2>The bar, in one row</h2>
    <p>Tabs and controls share a single row: pill tabs on the left, the address
    field taking the rest, actions at the end. Below it, one 2px loading line
    that glows while a page loads and one hairline — then the page.</p>
    <div class="plate" style="padding:0;overflow:hidden;margin-top:14px">
      <div class="chrome">
        <div class="row">
          <span class="ib" style="width:auto;padding:0 6px">{ic('globe', 22, acc)}</span>
          <span class="ib">{ic('back')}</span><span class="ib">{ic('forward')}</span>
          <span class="ib hot">{ic('reload')}</span><span class="ib">{ic('home')}</span>
          <div class="tabs">
            <div class="tab on"><span class="t">Interface — Styling</span>
              <span class="ib" style="width:20px;height:20px">{ic('close', 13)}</span></div>
            <div class="tab"><span class="t">Docs</span></div>
            <div class="tab"><span style="color:var(--accent)">{ic('folder', 14)}</span>
              <span class="t">4 tabs</span></div>
            <span class="ib">{ic('plus', 17)}</span>
          </div>
          <div class="addr"><span style="color:var(--accent)">{ic('shield-on', 16)}</span>
            <span>interface.app<span style="color:var(--dim)">/design</span></span>
            <span style="margin-left:auto;color:var(--dim)">{ic('star', 16)}</span></div>
          {''.join(f'<span class="ib">{ic(a)}</span>' for a in chrome_acts[:4])}
          {''.join(f'<span class="ib">{ic(a)}</span>' for a in chrome_acts[4:])}
        </div>
        <div class="prog"><i></i></div>
      </div>
      <div style="padding:14px 16px;color:var(--dim);font-size:12.5px">
        The tab you are on lifts off the bar with a faint accent halo; a tab
        group is a folder pill with a count. Nothing else in the row is
        coloured.</div>
    </div></section>""")

    # ---- home
    h.append(f"""<section><h2>Home</h2>
    <p>A greeting, one field, your shortcuts. The page sits in a wide aperture
    of accent light rather than a flat background, so the field reads as the
    thing to touch.</p>
    <div class="plate" style="padding:0;overflow:hidden;margin-top:14px">
      <div class="home">
        <div style="display:flex;align-items:center;gap:10px;justify-content:center">
          <span style="color:var(--accent)">{ic('globe', 28)}</span>
          <b style="font-size:16px">Interface</b></div>
        <div class="greet" style="margin-top:10px">Good evening · Wednesday, September 3</div>
        <div class="search"><div class="field focus" style="padding:15px 16px">
          <span style="color:var(--accent)">{ic('search', 18)}</span>
          <span style="color:var(--dim)">Search or type an address</span></div></div>
        <div class="dials">
          {''.join(f'<div class="dial"><div class="tile">{ic(k, 26)}</div>'
                    f'<div class="cap">{v}</div></div>' for k, v in tiles)}
        </div>
        <div class="legend" style="justify-content:center">
          <span>{ic('star', 14)} Bookmarks</span><span>{ic('clock', 14)} History</span>
          <span>{ic('download', 14)} Downloads</span><span>{ic('folder', 14)} Files</span>
        </div>
      </div>
    </div></section>""")

    # ---- panel
    h.append(f"""<section><h2>A panel, and the one selection cue</h2>
    <p>Selected rows in every list take an accent bar down the leading edge.
    One cue, used everywhere: bookmarks, history, downloads, files, settings.</p>
    <div class="split" style="margin-top:14px">
      <div class="list" style="padding:0;overflow:hidden">
        <div class="bar">
          <span class="ib">{ic('up', 16)}</span>
          <div class="crumbs"><b>Home</b>{ic('chevron-right', 13)}
            <b>Projects</b>{ic('chevron-right', 13)}<b>Interface</b></div>
          <span class="ib">{ic('list', 16)}</span><span class="ib">{ic('sort', 16)}</span>
          <span class="ib">{ic('plus', 16)}</span>
        </div>
        <div style="padding:6px">
          {''.join(
              f'<div class="it{" on" if i == 1 else ""}"><span style="color:var(--accent)">{ic(k, 18)}</span>'
              f'<span class="n">{nm}</span><span class="m">{sz}</span></div>'
              for i, (k, nm, sz) in enumerate(files))}
        </div>
        <div style="padding:10px">
          <div class="selbar"><span style="color:var(--accent)">{ic('check', 15)}</span>
            <span>1 selected</span><span style="margin-left:auto">{ic('copy', 15)}</span>
            <span>{ic('move', 15)}</span><span>{ic('trash', 15)}</span></div>
        </div>
      </div>
      <div class="plate">
        <h3>Why the bar, not a highlight</h3>
        <p>A wash alone disappears at a glance and competes with hover. The
        bar sits on the edge the row opens toward, so the eye follows it into
        the page. It is the accent colour, which the rest of the panel never
        uses for anything idle.</p>
        <div style="margin-top:16px" class="menu">
          <div class="it on"><span style="color:var(--accent)">{ic('reader', 16)}</span> Reader view</div>
          <div class="it"><span style="color:var(--dim)">{ic('reading-list', 16)}</span> Save to list</div>
          <div class="it"><span style="color:var(--dim)">{ic('print', 16)}</span> Print</div>
          <div class="it"><span style="color:var(--dim)">{ic('key', 16)}</span> Site info</div>
        </div>
        <p style="margin-top:12px">Menus keep the tight corner at the top left:
        the corner points back at the control that opened them.</p>
      </div>
    </div></section>""")

    # ---- welcome
    h.append(f"""<section><h2>Welcome</h2>
    <p>Three slides: the brand, a look to pick, the privacy promise. The
    content centres when the window is tall and scrolls when it is not, so no
    slide can run past its box at any text size.</p>
    <div class="split" style="margin-top:14px">
      <div class="welcome">
        <div class="mark">{ic('palette', 30)}</div>
        <h3 style="font-size:30px;line-height:1.15">Make it yours</h3>
        <p style="margin:12px auto 0">Pick a look now, change it later in
        Settings. You can also put your own picture behind the app.</p>
        <div class="row" style="justify-content:center;margin-top:22px">
          <span class="chip">{ic('sun', 14)} Light</span>
          <span class="chip" style="border-color:var(--accent)">{ic('moon', 14)} Dark</span>
          <span class="chip">{ic('contrast', 14)} B&amp;W</span>
        </div>
        <div class="stitch"><i class="on"></i><i></i><i></i></div>
        <div style="margin-top:20px"><span class="btn">{ic('forward', 16)} Start browsing</span></div>
      </div>
      <div class="plate">
        <h3>Icons</h3>
        <p>115 glyphs drawn on a 24pt grid: a 1.7pt primary stroke, a 1.35pt
        detail stroke, round caps and joins, and the same chamfer as the
        surfaces, so a folder in the bar and a folder on the page are the same
        drawing. They recolour to the text they sit beside — nothing is baked
        to a background.</p>
        <div class="legend">
          <span>24 × 24 box</span><span>2.4pt air</span><span>one weight</span>
          <span>chamfered corner</span><span>no emoji</span>
        </div>
      </div>
    </div></section>""")

    # ---- type
    h.append(f"""<section><h2>Type</h2>
    <div class="grid types" style="margin-top:12px">
      <div><span class="tag">hero 30 / 700</span>
        <div style="font-size:30px;font-weight:700;line-height:1.15">Good evening</div></div>
      <div><span class="tag">title 15.5 / 700</span>
        <div style="font-size:15.5px;font-weight:700">Make it yours</div></div>
      <div><span class="tag">body 13.5 / 400 · tracking .08</span>
        <div>Ads and trackers are blocked from the first page load. Tap the
        shield any time to see what happened on a page.</div></div>
      <div><span class="tag">caption 12 / 400 · tracking .15</span>
        <div style="font-size:12px;letter-spacing:.15px;color:var(--dim)">
        12 blocked · 4 saved · 1.4 MB</div></div>
    </div></section>""")

    # ---- the icon set
    h.append('<section><h2>The whole set</h2>'
             '<p>Every glyph the app draws. Hover one to see its name box.</p>'
             '<div class="icons" style="margin-top:14px">')
    for name in icon_names:
        h.append(f'<div class="ic">{icon(name, 26, "currentColor")}'
                 f'<span class="mono">{name}</span></div>')
    h.append('</div></section>')

    h.append('<hr><p style="margin-top:18px">Generated from the app: '
             '<span class="mono">python3 tool/build_design_preview.py</span> — '
             'colours come from lib/core/palette.dart, icons from assets/icons/, '
             'radii from lib/core/ui.dart.</p>')
    h.append('</div>')
    return '\n'.join(h)


def css_for(theme):
    P = lambda k: pal(theme, k)  # noqa: E731
    t = CSS
    t = t.replace('__BG__', P('background'))
    t = t.replace('__SURF__', P('surface'))
    t = t.replace('__SURFALT__', P('surfaceAlt'))
    t = t.replace('__FIELD__', P('omniboxFill'))
    t = t.replace('__CHROME__', P('chromeFill'))
    t = t.replace('__TEXT__', P('text'))
    t = t.replace('__DIM__', P('textDim'))
    t = t.replace('__FAINT__', rgba(P('textDim'), .72))
    t = t.replace('__BORDER__', P('border'))
    t = t.replace('__ACCENT__', P('accent'))
    t = t.replace('__PRIMARY__', P('primary'))
    t = t.replace('__ONPRIM__', P('onPrimary'))

    def tint(m):
        return rgba(P('accent'), float(m.group(1)))
    t = re.sub(r'rgba\(34, ?211, ?238, ?([0-9.]+)\)', tint, t)
    return t


JS = """
document.querySelectorAll('button#dark,button#light').forEach(function (b) {
  b.addEventListener('click', function () {
    var t = b.id;
    document.documentElement.setAttribute('data-theme', t);
    document.querySelector('button#dark').setAttribute('aria-pressed', t === 'dark');
    document.querySelector('button#light').setAttribute('aria-pressed', t === 'light');
    var css = document.getElementById('theme-css');
    css.textContent = (t === 'light') ? LIGHT : DARK;
  });
});
"""


def main():
    dark = css_for('dark')
    light = css_for('light')
    html = ('<!doctype html>\n<html lang="en" data-theme="dark">\n<head>\n'
            '<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
            '<title>Interface — the chamfer</title>\n'
            f'<style id="theme-css">{dark}</style>\n</head>\n<body>\n'
            + body() +
            f'\n<script>var LIGHT = {light!r}; var DARK = {dark!r};\n' + JS +
            '</script>\n</body>\n</html>\n')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        f.write(html)
    print(f'wrote design/index.html ({len(html) // 1024} KB)')


if __name__ == '__main__':
    main()
