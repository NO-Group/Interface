/// Small persisted data models (JSON-serializable).
library;


class Bookmark {
  const Bookmark({required this.url, required this.title});

  final String url;
  final String title;

  Map<String, dynamic> toJson() => {'url': url, 'title': title};

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );

  Bookmark copyWith({String? url, String? title}) => Bookmark(
        url: url ?? this.url,
        title: title ?? this.title,
      );

  @override
  bool operator ==(Object other) => other is Bookmark && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

class HistoryEntry {
  const HistoryEntry({
    required this.url,
    required this.title,
    required this.visitedAt,
  });

  final String url;
  final String title;

  /// Epoch milliseconds.
  final int visitedAt;

  Map<String, dynamic> toJson() =>
      {'url': url, 'title': title, 'at': visitedAt};

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        visitedAt: json['at'] as int? ?? 0,
      );
}

/// A colored tab group (Chrome-style).
class TabGroup {
  TabGroup({
    required this.id,
    required this.name,
    required this.colorIndex,
  });

  final String id;
  String name;
  final int colorIndex;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'color': colorIndex};

  factory TabGroup.fromJson(Map<String, dynamic> json) => TabGroup(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Group',
        colorIndex: json['color'] as int? ?? 0,
      );

  TabGroup copyWith({String? name, int? colorIndex}) => TabGroup(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
      );

  static const colors = <int>[
    0xFF22D3EE, // cyan
    0xFF7C9EFF, // indigo
    0xFFFFB74D, // orange
    0xFF81C784, // green
    0xFFF06292, // pink
    0xFFBA68C8, // purple
    0xFFFFD54F, // yellow
    0xFF4DB6AC, // teal
  ];

  int get colorValue => colors[colorIndex.clamp(0, colors.length - 1)];
}

/// "Read later" entry.
class ReadingEntry {
  const ReadingEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.addedAt,
    this.read = false,
  });

  final String id;
  final String url;
  final String title;
  final int addedAt;
  final bool read;

  Map<String, dynamic> toJson() =>
      {'id': id, 'url': url, 'title': title, 'at': addedAt, 'read': read};

  factory ReadingEntry.fromJson(Map<String, dynamic> json) => ReadingEntry(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        addedAt: json['at'] as int? ?? 0,
        read: json['read'] as bool? ?? false,
      );

  ReadingEntry copyWith({bool? read, String? title}) => ReadingEntry(
        id: id,
        url: url,
        title: title ?? this.title,
        addedAt: addedAt,
        read: read ?? this.read,
      );
}

/// Per-site override. `null` fields fall back to the global setting.
class SiteRule {
  const SiteRule({
    required this.host,
    this.blockAds,
    this.javaScript,
    this.desktopSite,
    this.media,
  });

  final String host;
  final bool? blockAds;
  final bool? javaScript;
  final bool? desktopSite;

  /// Camera / microphone / geolocation prompts.
  final bool? media;

  Map<String, dynamic> toJson() => {
        'host': host,
        if (blockAds != null) 'ads': blockAds,
        if (javaScript != null) 'js': javaScript,
        if (desktopSite != null) 'desktop': desktopSite,
        if (media != null) 'media': media,
      };

  factory SiteRule.fromJson(Map<String, dynamic> json) => SiteRule(
        host: json['host'] as String? ?? '',
        blockAds: json['ads'] as bool?,
        javaScript: json['js'] as bool?,
        desktopSite: json['desktop'] as bool?,
        media: json['media'] as bool?,
      );

  SiteRule copyWith({
    bool? blockAds,
    bool? javaScript,
    bool? desktopSite,
    bool? media,
    bool clearAds = false,
    bool clearJs = false,
    bool clearDesktop = false,
    bool clearMedia = false,
  }) =>
      SiteRule(
        host: host,
        blockAds: clearAds ? null : (blockAds ?? this.blockAds),
        javaScript: clearJs ? null : (javaScript ?? this.javaScript),
        desktopSite:
            clearDesktop ? null : (desktopSite ?? this.desktopSite),
        media: clearMedia ? null : (media ?? this.media),
      );

  bool get isAllDefault =>
      blockAds == null &&
      javaScript == null &&
      desktopSite == null &&
      media == null;
}

/// A speed-dial folder.
class SpeedDialFolder {
  SpeedDialFolder({required this.id, required this.name});

  final String id;
  String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory SpeedDialFolder.fromJson(Map<String, dynamic> json) =>
      SpeedDialFolder(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Folder',
      );
}

class SpeedDialItem {
  const SpeedDialItem({
    required this.id,
    required this.title,
    required this.url,
    this.folderId,
  });

  final String id;
  final String title;
  final String url;
  final String? folderId;

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'url': url, if (folderId != null) 'f': folderId};

  factory SpeedDialItem.fromJson(Map<String, dynamic> json) => SpeedDialItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        folderId: json['f'] as String?,
      );

  SpeedDialItem copyWith({String? title, String? url, String? folderId}) =>
      SpeedDialItem(
        id: id,
        title: title ?? this.title,
        url: url ?? this.url,
        folderId: folderId ?? this.folderId,
      );
}

enum DownloadStatus { running, done, failed, cancelled }

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savedDir,
  });

  final String id;
  final String url;
  String fileName;
  String savedDir;
  String? path;
  int received = 0;
  int total = 0;
  DownloadStatus status = DownloadStatus.running;
  String? error;

  bool get isRunning => status == DownloadStatus.running;

  String get statusLabel {
    switch (status) {
      case DownloadStatus.running:
        return total > 0
            ? '${(received / total * 100).clamp(0, 100).toStringAsFixed(0)}% of ${_fmt(total)}'
            : _fmt(received);
      case DownloadStatus.done:
        return 'Completed — ${_fmt(total > 0 ? total : received)}';
      case DownloadStatus.failed:
        return 'Failed${error == null ? '' : ': $error'}';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  static String _fmt(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
