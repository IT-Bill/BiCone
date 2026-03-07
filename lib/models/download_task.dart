import 'package:dio/dio.dart';
import 'video_item.dart';

enum DownloadPhase { preparing, downloadingVideo, downloadingAudio, merging }

class StreamProgress {
  int receivedBytes = 0;
  int totalBytes = 0;
  double speed = 0;
  DateTime? _lastSpeedUpdate;
  int _lastReceivedBytes = 0;
  DateTime? _startTime;
  String? completeDuration;

  double get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get formattedSize {
    final received = _formatBytes(receivedBytes);
    final total = totalBytes > 0 ? _formatBytes(totalBytes) : '?';
    return '$received / $total';
  }

  String get formattedSpeed {
    if (speed <= 0) return '';
    if (speed >= 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speed / 1024).toStringAsFixed(0)} KB/s';
  }

  String get formattedEta {
    if (speed <= 0 || totalBytes <= 0) return '';
    final remaining = totalBytes - receivedBytes;
    final seconds = (remaining / speed).round();
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m${seconds % 60}s';
    return '${seconds ~/ 3600}h${(seconds % 3600) ~/ 60}m';
  }

  void update(int received, int total) {
    receivedBytes = received;
    totalBytes = total;
    _startTime ??= DateTime.now();

    final now = DateTime.now();
    if (_lastSpeedUpdate != null) {
      final elapsed = now.difference(_lastSpeedUpdate!).inMilliseconds;
      if (elapsed >= 500) {
        final bytesDelta = received - _lastReceivedBytes;
        speed = bytesDelta / (elapsed / 1000);
        _lastSpeedUpdate = now;
        _lastReceivedBytes = received;
      }
    } else {
      _lastSpeedUpdate = now;
      _lastReceivedBytes = received;
    }
  }

  void markComplete() {
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      if (elapsed < 60) {
        completeDuration = '${elapsed}s';
      } else if (elapsed < 3600) {
        completeDuration = '${elapsed ~/ 60}m${elapsed % 60}s';
      } else {
        completeDuration =
            '${elapsed ~/ 3600}h${(elapsed % 3600) ~/ 60}m';
      }
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

class DownloadTask {
  final VideoItem video;
  double progress; // overall progress 0.0-1.0
  DownloadStatus status;
  CancelToken? cancelToken;
  DownloadPhase phase;
  final StreamProgress videoStream = StreamProgress();
  final StreamProgress audioStream = StreamProgress();
  final StreamProgress mergeStream = StreamProgress();

  DownloadTask({
    required this.video,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.cancelToken,
    this.phase = DownloadPhase.preparing,
  });
}
