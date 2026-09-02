/// Built-in list of common ad / tracker / pop-under hosts.
///
/// Matched by host *suffix* so `ads.example.doubleclick.net` is caught too.
/// Opt-in/opt-out at any time from the menu ("Block ads & pop-ups").
const kBlockedHosts = <String>{
  // Google ads & tracking
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'adservice.google.com',
  'pagead2.googlesyndication.com',
  'google-analytics.com',
  'googletagmanager.com',
  'googletagservices.com',
  'ads.youtube.com',
  'app-measurement.com',
  'firebaseinstallations.googleapis.com',
  // Major ad exchanges / SSPs / DSPs
  'adnxs.com',
  'adnxs-simple.com',
  'rubiconproject.com',
  'pubmatic.com',
  'openx.net',
  'criteo.com',
  'criteo.net',
  'casalemedia.com',
  'smartadserver.com',
  'adform.net',
  'teads.tv',
  'sharethrough.com',
  '33across.com',
  'bidswitch.net',
  'rtbhouse.com',
  'sonobi.com',
  'yieldmo.com',
  'spotxchange.com',
  'spotx.tv',
  'springserve.com',
  'adcolony.com',
  'applovin.com',
  'unityads.unity3d.com',
  'vungle.com',
  'ironsrc.com',
  'mopub.com',
  'inmobi.com',
  'chartboost.com',
  'tapjoy.com',
  'fyfe.com',
  'media.net',
  'amazon-adsystem.com',
  'advertising.com',
  'adtechus.com',
  'onetag-sys.com',
  'bidr.io',
  'clean.io',
  // Native / content ads
  'taboola.com',
  'outbrain.com',
  'outbrainimg.com',
  'revcontent.com',
  'mgid.com',
  'zergnet.com',
  'engageya.com',
  'plista.com',
  // Pop-unders & redirects
  'popads.net',
  'popcash.net',
  'propellerads.com',
  'propellerclick.com',
  'adsterra.com',
  'adsterranetwork.com',
  'clickadu.com',
  'hilltopads.net',
  'adcash.com',
  'exoclick.com',
  'juicyads.com',
  'trafficjunky.com',
  'zeropark.com',
  'clickaine.com',
  'onclickads.net',
  'onclasrv.com',
  'popunder.net',
  'popmyads.com',
  // Analytics / trackers / fingerprinting
  'scorecardresearch.com',
  'quantserve.com',
  'quantcount.com',
  'moatads.com',
  'moatpixel.com',
  'branch.io',
  'appsflyer.com',
  'adjust.com',
  'kochava.com',
  'amplitude.com',
  'mixpanel.com',
  'segment.io',
  'segment.com',
  'hotjar.com',
  'hotjar.io',
  'mouseflow.com',
  'fullstory.com',
  'clarity.ms',
  'newrelic.com',
  'nr-data.net',
  'bugsnag.com',
  'crashlytics.com',
  // Malvertsing / shady domains
  'adnium.com',
  'adcron.com',
  'aducdn.com',
  'vuukle.com',
  'disqusads.com',
  'zedo.com',
  'vidoomy.com',
  'vidoomymedia.com',
  'lifthusiad.com',
  'servenetwork.com',
  'highperformancecpm.com',
  'effectivegatecpm.com',
  'effectiveratecpm.com',
  'toprevenuegate.com',
  'revenuemantra.com',
  'shihuahuanet.com',
};

final List<String> _sortedBlockedHosts = kBlockedHosts.toList()..sort();

/// True when [host] (or one of its parents) is on the blocklist.
bool isBlockedHost(String host) {
  if (host.isEmpty) return false;
  final h = host.toLowerCase();
  String part = h;
  while (true) {
    final idx = _binarySearch(part);
    if (idx) return true;
    final dot = part.indexOf('.');
    if (dot < 0 || dot == part.length - 1) return false;
    part = part.substring(dot + 1);
  }
}

bool _binarySearch(String host) {
  var lo = 0, hi = _sortedBlockedHosts.length - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final cmp = _sortedBlockedHosts[mid].compareTo(host);
    if (cmp == 0) return true;
    if (cmp < 0) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return false;
}
