import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import '../models/video_item.dart';

/// Parses the RSSHub feed for a Bilibili user's videos.
class RssService {
  final Dio _dio = Dio();
  final String rssHubUrl;
  final String rssMode;

  RssService({required this.rssHubUrl, this.rssMode = 'dynamic'});

  /// Maximum retries for 503 (cache miss) responses from RSSHub.
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 3);

  Future<List<VideoItem>> getLatestVideos(int uid, {int retry = 0}) async {
    try {
      final path = rssMode == 'video'
          ? '/bilibili/user/video/$uid'
          : '/bilibili/user/dynamic/$uid/disableEmbed=1';
      final response = await _dio.get(
        '$rssHubUrl$path',
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final document = XmlDocument.parse(response.data.toString());
      final items = document.findAllElements('item');
      final videos = <VideoItem>[];

      for (final item in items) {
        final title =
            item.findElements('title').firstOrNull?.innerText ?? '';
        final link =
            item.findElements('link').firstOrNull?.innerText ?? '';
        final pubDate =
            item.findElements('pubDate').firstOrNull?.innerText ?? '';
        final author =
            item.findElements('author').firstOrNull?.innerText ?? '';
        final description =
            item.findElements('description').firstOrNull?.innerText ?? '';

        String bvid = '';
        String videoLink = '';

        if (rssMode == 'video') {
          // Video endpoint: BV ID is in <link> or <guid>
          final bvMatchLink = RegExp(r'BV[\w]+').firstMatch(link);
          if (bvMatchLink != null) {
            bvid = bvMatchLink.group(0)!;
          } else {
            final guid =
                item.findElements('guid').firstOrNull?.innerText ?? '';
            final bvMatchGuid = RegExp(r'BV[\w]+').firstMatch(guid);
            bvid = bvMatchGuid?.group(0) ?? '';
          }
          videoLink = link.isNotEmpty
              ? link
              : 'https://www.bilibili.com/video/$bvid';
        } else {
          // Dynamic endpoint: filter to video posts only
          if (!description.contains('视频地址：')) continue;
          if (description.contains('转发自:')) continue;
          final bvMatch = RegExp(r'BV[\w]+').firstMatch(description);
          if (bvMatch != null) {
            bvid = bvMatch.group(0)!;
          }
          videoLink = 'https://www.bilibili.com/video/$bvid';
        }

        // Extract thumbnail specifically from <img> tags in description HTML
        String thumbnail = '';
        final imgTagMatch =
            RegExp(r'<img[^>]+src="([^"]+)"').firstMatch(description);
        if (imgTagMatch != null) {
          thumbnail = imgTagMatch.group(1) ?? '';
        }
        if (thumbnail.startsWith('//')) {
          thumbnail = 'https:$thumbnail';
        }

        if (bvid.isNotEmpty) {
          videos.add(VideoItem(
            bvid: bvid,
            title: title,
            author: author,
            authorMid: uid,
            thumbnail: thumbnail,
            pubDate: pubDate,
            description: description,
            link: videoLink,
          ));
        }
      }

      debugPrint('RSS feed for uid=$uid (mode=$rssMode): found ${videos.length} videos');
      return videos;
    } on DioException catch (e) {
      // RSSHub returns 503 when the feed cache is not yet built — retry
      if (e.response?.statusCode == 503 && retry < _maxRetries) {
        debugPrint(
            'RSS 503 for uid=$uid, retrying (${retry + 1}/$_maxRetries)…');
        await Future.delayed(_retryDelay);
        return getLatestVideos(uid, retry: retry + 1);
      }
      debugPrint('RSS parsing error for uid=$uid: $e');
      return [];
    } catch (e) {
      debugPrint('RSS parsing error for uid=$uid: $e');
      return [];
    }
  }

  /// Check if a specific BV号 still appears in the UP主's RSSHub feed.
  /// Returns `true` if found (video is still valid), `false` if not found,
  /// and `null` if the check failed (network error, etc.).
  Future<bool?> checkVideoExists(int uid, String bvid) async {
    try {
      final videos = await getLatestVideos(uid);
      if (videos.isEmpty) return null; // feed is empty or errored
      return videos.any((v) => v.bvid == bvid);
    } catch (e) {
      debugPrint('RSS checkVideoExists error: $e');
      return null;
    }
  }
}
