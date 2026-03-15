import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/subscription.dart';
import '../models/video_item.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class DemoService {
  static const String reviewUserId = '20260315';
  static const String reviewUserName = 'BiCone App Review';

  static Future<void> seedAppReviewDemo({
    required StorageService storage,
    required AuthService auth,
  }) async {
    await auth.logout();
    await storage.clearSubscriptions();
    await storage.clearVideos();

    if (!kIsWeb && Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      final dlDir = Directory('${docs.path}/Downloads');
      if (!await dlDir.exists()) {
        await dlDir.create(recursive: true);
      }
      await storage.setDownloadPath(dlDir.path);
    }

    await storage.setAutoDownload(false);
    await storage.setHideUndownloaded(false);
    await storage.setSaveCover(true);
    await storage.setCheckInterval(3);
    await storage.setRssMode('dynamic');

    await auth.enterAppReviewMode(
      userId: reviewUserId,
      userName: reviewUserName,
    );

    final now = DateTime.now().toUtc();
    final subscriptions = <Subscription>[
      Subscription(
        mid: 1001001,
        name: '影视飓风',
        sign: '4K / 影像 / 器材',
        addedAt: now.subtract(const Duration(days: 14)),
      ),
      Subscription(
        mid: 1001002,
        name: '老师好我叫何同学',
        sign: '科技 / 数码 / 生活方式',
        addedAt: now.subtract(const Duration(days: 10)),
      ),
      Subscription(
        mid: 1001003,
        name: '小约翰可汗',
        sign: '历史 / 地理 / 长视频',
        addedAt: now.subtract(const Duration(days: 7)),
        downloadPaused: true,
        keywords: const ['历史', '国家'],
      ),
    ];

    for (final sub in subscriptions) {
      await storage.addSubscription(sub);
    }

    final videos = <VideoItem>[
      VideoItem(
        bvid: 'BV1RV411demo',
        title: 'App Review 演示：最新一期视频（未下载）',
        author: '影视飓风',
        authorMid: 1001001,
        pubDate: now.subtract(const Duration(hours: 2)).toIso8601String(),
        description: '用于 Apple App Review / TestFlight 的静态演示数据。',
        link: 'https://example.com/app-review/feed-1',
      ),
      VideoItem(
        bvid: 'BV1RV412demo',
        title: '已经下载完成的视频示例',
        author: '影视飓风',
        authorMid: 1001001,
        pubDate: now.subtract(const Duration(days: 1)).toIso8601String(),
        description: '展示已完成下载状态。',
        link: 'https://example.com/app-review/feed-2',
      ),
      VideoItem(
        bvid: 'BV1RV413demo',
        title: '暂停中的下载任务示例',
        author: '老师好我叫何同学',
        authorMid: 1001002,
        pubDate: now.subtract(const Duration(hours: 18)).toIso8601String(),
        description: '展示暂停后可继续下载。',
        link: 'https://example.com/app-review/feed-3',
      ),
      VideoItem(
        bvid: 'BV1RV414demo',
        title: '可重试的失败视频示例',
        author: '老师好我叫何同学',
        authorMid: 1001002,
        pubDate: now.subtract(const Duration(days: 2)).toIso8601String(),
        description: '展示失败状态和重试入口。',
        link: 'https://example.com/app-review/feed-4',
      ),
      VideoItem(
        bvid: 'BV1RV415demo',
        title: '已失效视频示例',
        author: '小约翰可汗',
        authorMid: 1001003,
        pubDate: now.subtract(const Duration(days: 3)).toIso8601String(),
        description: '展示失效视频的恢复/删除逻辑。',
        link: 'https://example.com/app-review/feed-5',
      ),
      VideoItem(
        bvid: 'BV1RV416demo',
        title: '已忽略视频示例',
        author: '小约翰可汗',
        authorMid: 1001003,
        pubDate: now.subtract(const Duration(days: 4)).toIso8601String(),
        description: '展示已忽略视频。',
        link: 'https://example.com/app-review/feed-6',
      ),
      VideoItem(
        bvid: 'BV1RV417demo',
        title: '收藏向长视频样本：国家、地图与历史',
        author: '小约翰可汗',
        authorMid: 1001003,
        pubDate: now.subtract(const Duration(days: 5)).toIso8601String(),
        description: '用于测试搜索和关键词过滤。',
        link: 'https://example.com/app-review/feed-7',
      ),
    ];

    for (final video in videos) {
      await storage.saveVideo(video);
    }

    await storage.updateVideoStatus(
      'BV1RV412demo',
      DownloadStatus.completed,
      progress: 1.0,
      fileSize: 268435456,
    );
    await storage.updateVideoStatus(
      'BV1RV413demo',
      DownloadStatus.paused,
      progress: 0.43,
    );
    await storage.updateVideoStatus(
      'BV1RV414demo',
      DownloadStatus.failed,
      progress: 0.0,
    );
    await storage.updateVideoStatus(
      'BV1RV415demo',
      DownloadStatus.invalidated,
      progress: 0.0,
    );
    await storage.updateVideoStatus(
      'BV1RV416demo',
      DownloadStatus.deleted,
      progress: 0.0,
    );
  }
}
