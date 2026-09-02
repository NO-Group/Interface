/// Small persisted data models (JSON-serializable).

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

class SpeedDialItem {
  const SpeedDialItem({required this.id, required this.title, required this.url});

  final String id;
  final String title;
  final String url;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'url': url};

  factory SpeedDialItem.fromJson(Map<String, dynamic> json) => SpeedDialItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  SpeedDialItem copyWith({String? title, String? url}) => SpeedDialItem(
        id: id,
        title: title ?? this.title,
        url: url ?? this.url,
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
  final String savedDir;
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
