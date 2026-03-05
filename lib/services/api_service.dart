import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// DASH stream URLs returned by the Bilibili playurl API.
class DashStreamInfo {
  final String videoUrl;
  final String audioUrl;
  final int quality;

  DashStreamInfo({
    required this.videoUrl,
    required this.audioUrl,
    required this.quality,
  });
}

/// Bilibili API helper with WBI request signing.
class ApiService {
  final Dio _dio = Dio();
  final StorageService _storage;

  String? _imgKey;
  String? _subKey;
  DateTime? _wbiKeysFetchedAt;

  // WBI mixin-key encoding table
  static const List<int> _mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
  ];

  ApiService(this._storage) {
    _dio.options.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    _dio.options.headers['Referer'] = 'https://www.bilibili.com';
  }

  String? get _sessdata => _storage.sessdata;

  Options get _authOptions => Options(
        headers: {
          if (_sessdata != null) 'Cookie': 'SESSDATA=$_sessdata',
        },
      );

  // ─── WBI Signing ──────────────────────────────────────

  String _getMixinKey(String imgKey, String subKey) {
    final rawKey = imgKey + subKey;
    final buf = StringBuffer();
    for (final i in _mixinKeyEncTab) {
      if (i < rawKey.length) buf.write(rawKey[i]);
    }
    return buf.toString().substring(0, 32);
  }

  Future<void> _ensureWbiKeys() async {
    // Refresh if keys are missing or older than 12 hours (daily rotation)
    final needsRefresh = _imgKey == null ||
        _subKey == null ||
        _wbiKeysFetchedAt == null ||
        DateTime.now().difference(_wbiKeysFetchedAt!).inHours >= 12;
    if (!needsRefresh) return;
    debugPrint('WBI: Fetching keys... SESSDATA=${_sessdata != null ? "(set, ${_sessdata!.length} chars)" : "(null)"}');
    try {
      final resp = await _dio.get(
        'https://api.bilibili.com/x/web-interface/nav',
        options: _authOptions,
      );
      debugPrint('WBI: /nav response code=${resp.data['code']}, isLogin=${resp.data['data']?['isLogin']}');
      // wbi_img is returned even when not logged in (code == -101)
      final wbi = resp.data['data']?['wbi_img'];
      if (wbi != null) {
        _imgKey = (wbi['img_url'] as String).split('/').last.split('.').first;
        _subKey = (wbi['sub_url'] as String).split('/').last.split('.').first;
        _wbiKeysFetchedAt = DateTime.now();
        debugPrint('WBI: Keys fetched. imgKey=${_imgKey!.substring(0, 8)}..., subKey=${_subKey!.substring(0, 8)}...');
      } else {
        debugPrint('WBI: wbi_img not found in response');
      }
    } catch (e) {
      debugPrint('WBI: Error fetching keys: $e');
    }
  }

  Map<String, String> _signParams(Map<String, String> params) {
    if (_imgKey == null || _subKey == null) return params;

    final mixinKey = _getMixinKey(_imgKey!, _subKey!);
    final wts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    final signed = Map<String, String>.from(params)..['wts'] = wts;
    final sortedKeys = signed.keys.toList()..sort();
    final queryParts = sortedKeys.map((k) {
      final v = signed[k]!.replaceAll(RegExp(r"[!'()*]"), '');
      return '${Uri.encodeComponent(k)}=${Uri.encodeComponent(v)}';
    });
    final qs = queryParts.join('&');
    signed['w_rid'] = md5.convert(utf8.encode(qs + mixinKey)).toString();
    return signed;
  }

  // ─── Public API ───────────────────────────────────────

  /// Fetch UP主 profile info by UID.
  /// Tries WBI-signed endpoint first, falls back to public card API.
  Future<Map<String, dynamic>?> getUserInfo(int mid) async {
    // Try the WBI-signed endpoint first
    try {
      await _ensureWbiKeys();
      final params = _signParams({'mid': mid.toString()});
      final resp = await _dio.get(
        'https://api.bilibili.com/x/space/wbi/acc/info',
        queryParameters: params,
        options: _authOptions,
      );
      if (resp.data['code'] == 0) return resp.data['data'];
    } catch (_) {}

    // Fallback: public card API (no WBI signing needed)
    try {
      final resp = await _dio.get(
        'https://api.bilibili.com/x/web-interface/card',
        queryParameters: {'mid': mid},
      );
      if (resp.data['code'] == 0) {
        final card = resp.data['data']['card'];
        return {
          'name': card['name'],
          'face': card['face'],
          'sign': card['sign'] ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  /// Fetch the logged-in user's own profile.
  Future<Map<String, dynamic>?> getMyInfo() async {
    try {
      debugPrint('API: getMyInfo SESSDATA=${_sessdata != null ? "(set)" : "(null)"}');
      final resp = await _dio.get(
        'https://api.bilibili.com/x/member/my',
        options: _authOptions,
      );
      debugPrint('API: getMyInfo code=${resp.data['code']}, message=${resp.data['message']}');
      if (resp.data['code'] == 0) {
        final data = resp.data['data'];
        debugPrint('API: Logged in as: ${data['name']} (mid=${data['mid']}, vipType=${data['vip']?['type']}, vipStatus=${data['vip']?['status']})');
        return data;
      }
    } catch (e) {
      debugPrint('API: getMyInfo error: $e');
    }
    return null;
  }

  /// Fetch video details by BV ID.
  Future<Map<String, dynamic>?> getVideoInfo(String bvid) async {
    try {
      final resp = await _dio.get(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': bvid},
        options: _authOptions,
      );
      if (resp.data['code'] == 0) return resp.data['data'];
    } catch (_) {}
    return null;
  }

  /// Get the direct download URL for a video.
  Future<DashStreamInfo?> getVideoDashStreams(
    String bvid,
    int cid, {
    int qn = 80,
  }) async {
    try {
      await _ensureWbiKeys();
      final params = _signParams({
        'bvid': bvid,
        'cid': cid.toString(),
        'qn': qn.toString(),
        'fnval': '16',
        'fnver': '0',
        'fourk': '1',
      });
      debugPrint('API: getVideoDashStreams bvid=$bvid, cid=$cid, requested qn=$qn');
      final resp = await _dio.get(
        'https://api.bilibili.com/x/player/wbi/playurl',
        queryParameters: params,
        options: _authOptions,
      );
      debugPrint('API: playurl code=${resp.data['code']}');
      if (resp.data['code'] == 0) {
        final data = resp.data['data'];
        final dash = data['dash'];
        if (dash == null) {
          debugPrint('API: playurl dash is null');
          return null;
        }
        debugPrint('API: playurl accept_quality=${data['accept_quality']}');
        debugPrint('API: playurl accept_description=${data['accept_description']}');

        // Select AVC (H.264, codecid=7) video stream
        final videos = (dash['video'] as List?) ?? [];
        final avcStreams = videos
            .where((v) => v['codecid'] == 7)
            .toList()
          ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));

        // Find best quality <= requested qn
        Map<String, dynamic>? selectedVideo;
        for (final v in avcStreams) {
          if ((v['id'] as int) <= qn) {
            selectedVideo = Map<String, dynamic>.from(v);
            break;
          }
        }
        selectedVideo ??= avcStreams.isNotEmpty
            ? Map<String, dynamic>.from(avcStreams.last)
            : null;

        if (selectedVideo == null) {
          debugPrint('API: No AVC video stream found');
          return null;
        }

        // Select best AAC audio (highest bandwidth)
        final audios = (dash['audio'] as List?) ?? [];
        if (audios.isEmpty) {
          debugPrint('API: No audio streams found');
          return null;
        }
        final sortedAudios = audios.toList()
          ..sort((a, b) =>
              (b['bandwidth'] as int).compareTo(a['bandwidth'] as int));

        final quality = selectedVideo['id'] as int;
        debugPrint('API: Selected video qn=$quality ${selectedVideo['codecs']}, '
            'audio id=${sortedAudios.first['id']} bandwidth=${sortedAudios.first['bandwidth']}');

        return DashStreamInfo(
          videoUrl: selectedVideo['baseUrl'] as String,
          audioUrl: sortedAudios.first['baseUrl'] as String,
          quality: quality,
        );
      } else {
        debugPrint('API: playurl failed: ${resp.data['message']}');
      }
    } catch (e) {
      debugPrint('API: getVideoDashStreams error: $e');
    }
    return null;
  }
}
