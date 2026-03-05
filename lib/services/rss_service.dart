import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import '../models/video_item.dart';

/// Parses the RSSHub feed for a Bilibili user's videos.
class RssService {
  final Dio _dio = Dio();
  final String rssHubUrl;

  RssService({required this.rssHubUrl});

  /// Maximum retries for 503 (cache miss) responses from RSSHub.
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 3);

  Future<List<VideoItem>> getLatestVideos(int uid, {int retry = 0}) async {
    try {
      final response = await _dio.get(
        '$rssHubUrl/bilibili/user/video/$uid',
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

        // Extract BV ID from link or guid
        String bvid = '';
        final bvMatchLink = RegExp(r'BV[\w]+').firstMatch(link);
        if (bvMatchLink != null) {
          bvid = bvMatchLink.group(0)!;
        } else {
          // Fallback: try guid element
          final guid =
              item.findElements('guid').firstOrNull?.innerText ?? '';
          final bvMatchGuid = RegExp(r'BV[\w]+').firstMatch(guid);
          bvid = bvMatchGuid?.group(0) ?? '';
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
            link: link.isNotEmpty
                ? link
                : 'https://www.bilibili.com/video/$bvid',
          ));
        }
      }

      debugPrint('RSS feed for uid=$uid: found ${videos.length} videos');
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
