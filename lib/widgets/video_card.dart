import 'package:flutter/cupertino.dart';
import '../models/video_item.dart';
import '../models/download_task.dart';
import 'compact_video_card.dart';
import 'full_video_card.dart';

export 'compact_video_card.dart';
export 'full_video_card.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPlay;
  final bool compact;
  final DownloadTask? downloadTask;

  const VideoCard({
    super.key,
    required this.video,
    this.onDownload,
    this.onDelete,
    this.onRestore,
    this.onPlay,
    this.compact = false,
    this.downloadTask,
  });

  @override
  Widget build(BuildContext context) {
    return compact
        ? CompactVideoCard(
            video: video,
            onDownload: onDownload,
            onDelete: onDelete,
            onRestore: onRestore,
            onPlay: onPlay,
            downloadTask: downloadTask,
          )
        : FullVideoCard(
            video: video,
            onDownload: onDownload,
            onDelete: onDelete,
            onRestore: onRestore,
            onPlay: onPlay,
            downloadTask: downloadTask,
          );
  }
}
