import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../theme.dart';

/// Format a date string (ISO 8601 or RFC 1123) to a relative time or short date.
String formatVideoDate(String dateStr) {
  try {
    // Try ISO 8601 first
    var date = DateTime.tryParse(dateStr);
    // Fallback: RFC 1123 / HTTP date
    date ??= HttpDate.parse(dateStr);
    // Convert to UTC+8
    date = date.toUtc().add(const Duration(hours: 8));
    return _relativeTime(date);
  } catch (_) {
    return dateStr.length > 16 ? dateStr.substring(0, 16) : dateStr;
  }
}

String _relativeTime(DateTime date) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && date.day == now.day) {
    return '${diff.inHours}小时前';
  }
  if (date.year == now.year) {
    return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// A tiny circular progress indicator painted with CustomPaint,
/// avoiding the need for Material's CircularProgressIndicator.
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      progress * 2 * 3.14159,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularProgressPainter old) =>
      old.progress != progress;
}

/// Build a mini circular progress widget.
Widget buildMiniProgress(double progress) {
  return CustomPaint(
    size: const Size(20, 20),
    painter: CircularProgressPainter(
      progress: progress,
      color: AppTheme.biliPink,
      trackColor: CupertinoColors.systemGrey4,
    ),
  );
}
