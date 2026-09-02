/// Reader-mode article extraction, executed in the page's JavaScript context.
///
/// A compact Readability-style heuristic: score containers by paragraph
/// text length and link density, then emit clean blocks as JSON.
const String kReaderJs = r'''
(function () {
  function visible(el) {
    try {
      var s = window.getComputedStyle(el);
      return s.display !== 'none' && s.visibility !== 'hidden' &&
        (el.offsetHeight > 0 || el.offsetWidth > 0);
    } catch (e) { return true; }
  }

  var nodes = document.querySelectorAll('article, main, div, section');
  var best = null, bestScore = 0;
  for (var i = 0; i < nodes.length; i++) {
    var n = nodes[i];
    if (!visible(n)) continue;
    var ps = n.querySelectorAll('p, blockquote, pre');
    var textLen = 0;
    for (var j = 0; j < ps.length; j++) {
      var t = (ps[j].textContent || '').replace(/\s+/g, ' ').trim();
      if (t.length > 40) textLen += t.length;
    }
    if (textLen < 220) continue;
    var links = n.querySelectorAll('a');
    var linkLen = 0;
    for (var q = 0; q < links.length; q++) {
      linkLen += (links[q].textContent || '').length;
    }
    var total = (n.textContent || '').length || 1;
    var linkDensity = Math.min(linkLen / total, 0.9);
    var penalty = n.querySelector('nav, header, footer, aside') ? 0.75 : 1.0;
    var score = textLen * (1 - linkDensity) * penalty;
    if (n.tagName === 'ARTICLE') score *= 1.2;
    if (score > bestScore) { bestScore = score; best = n; }
  }
  var root = best || document.body;

  var title = document.title || '';
  var og = document.querySelector('meta[property="og:title"]');
  if (og && og.getAttribute('content')) title = og.getAttribute('content');
  var h1 = root.querySelector('h1');
  if (!og && h1 && h1.textContent.trim().length > 3) title = h1.textContent.trim();

  var by = '';
  var meta = document.querySelector('meta[name="author"], meta[property="article:author"]');
  if (meta && meta.getAttribute('content')) {
    by = meta.getAttribute('content');
  } else {
    var b = root.querySelector('[rel="author"], .byline, .author, [itemprop="author"]');
    if (b) by = (b.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 80);
  }

  var hero = '';
  var ogi = document.querySelector('meta[property="og:image"]');
  if (ogi && ogi.getAttribute('content')) hero = ogi.getAttribute('content');
  if (!hero) {
    var im = root.querySelector('img');
    if (im && (im.naturalWidth > 300 || im.width > 300)) hero = im.src || '';
  }

  var out = [];
  var seen = {};
  var els = root.querySelectorAll('h2,h3,h4,p,li,blockquote,pre,img,figure');
  for (var k = 0; k < els.length && out.length < 700; k++) {
    var e = els[k];
    if (!visible(e)) continue;
    var tag = e.tagName.toLowerCase();
    if (tag === 'img' || tag === 'figure') {
      var src = '';
      if (tag === 'img') {
        src = e.getAttribute('src') || e.getAttribute('data-src') || '';
      } else {
        var fi = e.querySelector('img');
        if (fi) src = fi.getAttribute('src') || fi.getAttribute('data-src') || '';
      }
      if (src && (src.indexOf('http') === 0 || src.indexOf('data:image') === 0 ||
          src.indexOf('//') === 0)) {
        out.push({ t: 'img', v: src });
      }
      continue;
    }
    var txt = (e.textContent || '').replace(/\s+/g, ' ').trim();
    if (!txt) continue;
    var key = txt.slice(0, 80);
    if (seen[key]) continue;
    seen[key] = 1;
    if (tag === 'p' && txt.length < 30) continue;
    if (tag === 'li' && txt.length < 8) continue;
    if (txt.length > 5000) continue;
    var kind = tag === 'h4' ? 'h3' : tag;
    out.push({ t: kind, v: txt });
  }

  return JSON.stringify({ title: title, by: by, hero: hero, blocks: out });
})()
''';
