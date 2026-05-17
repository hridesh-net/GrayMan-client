import 'dart:io';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'worker_service.dart';
import '../core/networking/api_client.dart';

/// Offline reel queue — mirrors OfflineReelQueue.swift + RN reelUploader.
class OfflineReelQueue extends ChangeNotifier {
  OfflineReelQueue._();
  static final OfflineReelQueue instance = OfflineReelQueue._();

  static const _partSize = 5 * 1024 * 1024;

  final List<String> _pendingPaths = [];
  bool isFlushing = false;

  int get pendingCount => _pendingPaths.length;

  Future<void> enqueueRawRecording(String sourcePath) async {
    final dir = await getApplicationSupportDirectory();
    final reelsDir = Directory('${dir.path}/reels');
    if (!await reelsDir.exists()) await reelsDir.create(recursive: true);
    final dest = '${reelsDir.path}/reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(sourcePath).copy(dest);
    _pendingPaths.add(dest);
    notifyListeners();
    _tryFlush();
  }

  Future<void> flush() async => _tryFlush(force: true);

  String _contentTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'video/mp4';
  }

  Future<void> _tryFlush({bool force = false}) async {
    if (_pendingPaths.isEmpty || isFlushing) return;
    final conn = await Connectivity().checkConnectivity();
    if (!force && conn.contains(ConnectivityResult.none)) return;

    isFlushing = true;
    notifyListeners();

    while (_pendingPaths.isNotEmpty) {
      final path = _pendingPaths.first;
      try {
        await _uploadFile(path);
        _pendingPaths.removeAt(0);
        try {
          await File(path).delete();
        } catch (_) {}
      } catch (_) {
        break;
      }
    }

    isFlushing = false;
    notifyListeners();
  }

  Future<void> _uploadFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final contentType = _contentTypeFor(path);
    final partCount = math.max(1, (bytes.length / _partSize).ceil());
    final init = await WorkerService.instance.initReelMultipartUpload(partCount, contentType: contentType);

    final completed = <Map<String, dynamic>>[];

    try {
      for (final part in init.partURLs) {
        final start = (part.partNumber - 1) * _partSize;
        final end = math.min(start + _partSize, bytes.length);
        final chunk = bytes.sublist(start, end);
        final etag = await ApiClient.instance.uploadBytes(Uri.parse(part.url), chunk, contentType);
        completed.add({'part_number': part.partNumber, 'etag': etag});
      }

      completed.sort((a, b) => (a['part_number'] as int).compareTo(b['part_number'] as int));

      await WorkerService.instance.completeReelMultipartUpload(
        key: init.key,
        uploadID: init.uploadID,
        parts: completed,
      );
    } catch (e) {
      await WorkerService.instance.abortMultipartUpload(key: init.key, uploadID: init.uploadID);
      rethrow;
    }
  }
}
