import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models.dart';

/// Real streaming downloads with progress, cancellation and dedupe.
class DownloadService extends ChangeNotifier {
  final Map<String, http.Client> _active = {};
  final List<DownloadItem> items = [];
  DateTime _lastNotify = DateTime.now();

  List<DownloadItem> get downloads => List.unmodifiable(items);

  bool get hasActive => _active.isNotEmpty;

  void addFromRequest(DownloadStartRequest request) {
    final name = request.suggestedFilename?.isNotEmpty == true
        ? request.suggestedFilename!
        : _nameFromUrl(request.url.toString());
    final item = DownloadItem(
      id: 'dl-${DateTime.now().microsecondsSinceEpoch}',
      url: request.url.toString(),
      fileName: name,
      savedDir: '',
    );
    items.insert(0, item);
    _touch(force: true);
    unawaited(_run(item));
  }

  Future<void> _run(DownloadItem item) async {
    final client = http.Client();
    _active[item.id] = client;
    try {
      final dir = await _targetDir();
      await dir.create(recursive: true);
      item.savedDir = dir.path;
      item.fileName = _dedupe(dir, item.fileName);
      final file = File('${dir.path}${Platform.pathSeparator}${item.fileName}');
      item.path = file.path;

      final req = http.Request('GET', Uri.parse(item.url));
      req.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

      final response = await client.send(req);
      item.total = response.contentLength ?? 0;

      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          item.received += chunk.length;
          _touch();
        }
        await sink.flush();
        await sink.close();
        item.status = DownloadStatus.done;
      } catch (e) {
        try {
          await sink.close();
        } catch (_) {}
        rethrow;
      }
    } catch (e) {
      if (item.status == DownloadStatus.running) {
        item.status = e.toString().contains('ClientException') ||
                e.toString().contains('closed')
            ? DownloadStatus.cancelled
            : DownloadStatus.failed;
        item.error = e is http.ClientException
            ? e.message
            : e.toString().split('\n').first;
      }
    } finally {
      _active.remove(item.id);
      _touch(force: true);
    }
  }

  void cancel(String id) {
    _active[id]?.close();
  }

  void clearFinished() {
    items.removeWhere(
      (i) =>
          i.status == DownloadStatus.done ||
          i.status == DownloadStatus.failed ||
          i.status == DownloadStatus.cancelled,
    );
    _touch(force: true);
  }

  void _touch({bool force = false}) {
    final now = DateTime.now();
    if (force || now.difference(_lastNotify).inMilliseconds >= 150) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  /// Opens the containing folder (Windows: explorer with the file selected).
  Future<void> reveal(DownloadItem item) async {
    if (item.path == null) return;
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', item.path!]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', item.path!]);
      } else {
        await Process.run('xdg-open', [item.savedDir]);
      }
    } catch (e) {
      debugPrint('reveal failed: $e');
    }
  }

  String _dedupe(Directory dir, String name) {
    var candidate = name;
    if (candidate.isEmpty) candidate = 'download';
    var n = 1;
    while (File('${dir.path}${Platform.pathSeparator}$candidate').existsSync()) {
      final dot = candidate.lastIndexOf('.');
      candidate = dot > 0
          ? '${candidate.substring(0, dot)} ($n)${candidate.substring(dot)}'
          : '$candidate ($n)';
      n++;
    }
    return candidate;
  }

  String _nameFromUrl(String url) {
    final u = Uri.tryParse(url);
    final seg = u?.pathSegments;
    if (seg != null && seg.isNotEmpty && seg.last.isNotEmpty) {
      return Uri.decodeComponent(seg.last);
    }
    return 'download';
  }

  Future<Directory> _targetDir() async {
    if (Platform.isWindows || Platform.isMacOS) {
      final d = await getDownloadsDirectory();
      if (d != null) return d;
    }
    if (Platform.isAndroid) {
      try {
        final dirs =
            await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (dirs != null && dirs.isNotEmpty) return dirs.first;
      } catch (_) {}
      final d = await getExternalStorageDirectory();
      if (d != null) return d;
    }
    return getApplicationDocumentsDirectory();
  }
}
