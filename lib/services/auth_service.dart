import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

enum AuthState {
  notLoggedIn,
  generatingQr,
  qrReady,
  scanned,
  loggedIn,
  error,
}

class AuthService extends ChangeNotifier {
  final Dio _dio = Dio();
  final StorageService _storage;

  AuthState _state = AuthState.notLoggedIn;
  String? _qrUrl;
  String? _qrcodeKey;
  Timer? _pollTimer;
  String? _errorMessage;

  AuthState get state => _state;
  String? get qrUrl => _qrUrl;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _state == AuthState.loggedIn;
  String? get sessdata => _storage.sessdata;
  String? get userId => _storage.userId;
  String? get userName => _storage.userName;
  String? get userFace => _storage.userFace;

  AuthService(this._storage) {
    _dio.options.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  }

  /// Try to restore a previous login session from storage.
  Future<void> tryRestoreLogin() async {
    if (_storage.isAppReviewMode) {
      debugPrint('Auth: Restoring App Review demo session');
      _state = AuthState.loggedIn;
      notifyListeners();
      return;
    }

    if (!_storage.isLoggedIn) {
      debugPrint('Auth: Not logged in (no stored session)');
      _state = AuthState.notLoggedIn;
      notifyListeners();
      return;
    }

    debugPrint('Auth: Restoring login... SESSDATA=${_storage.sessdata!.substring(0, 8)}..., userId=${_storage.userId}');
    try {
      // Verify session is still valid
      final response = await _dio.get(
        'https://api.bilibili.com/x/member/my',
        options:
            Options(headers: {'Cookie': 'SESSDATA=${_storage.sessdata}'}),
      );
      debugPrint('Auth: /member/my code=${response.data['code']}');
      if (response.data['code'] == 0) {
        final myData = response.data['data'];
        debugPrint('Auth: Session valid! name=${myData['name']}, mid=${myData['mid']}, vipType=${myData['vip']?['type']}, vipStatus=${myData['vip']?['status']}');
        // Session valid – refresh user info via public API
        final uid = _storage.userId ?? '${response.data['data']['mid']}';
        try {
          final cardResp = await _dio.get(
            'https://api.bilibili.com/x/web-interface/card',
            queryParameters: {'mid': uid, 'photo': false},
          );
          if (cardResp.data['code'] == 0) {
            final card = cardResp.data['data']['card'];
            await _storage.saveAuth(
              sessdata: _storage.sessdata!,
              biliJct: _storage.biliJct ?? '',
              userId: uid,
              refreshToken: _storage.refreshToken ?? '',
              userName: card['name'],
              userFace: card['face'],
            );
          }
        } catch (_) {}
        _state = AuthState.loggedIn;
        notifyListeners();
        return;
      }

      // Server explicitly rejected the session – clear credentials
      await _storage.clearAuth();
      _state = AuthState.notLoggedIn;
      notifyListeners();
    } catch (_) {
      // Network error / timeout – keep stored credentials and treat as
      // logged-in so the user is not forced to re-login due to a
      // transient network issue.
      _state = AuthState.loggedIn;
      notifyListeners();
    }
  }

  /// Request a new QR code for login.
  Future<void> generateQRCode() async {
    _state = AuthState.generatingQr;
    notifyListeners();

    try {
      final response = await _dio.get(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
      );

      if (response.data['code'] != 0) {
        _state = AuthState.error;
        _errorMessage = '获取二维码失败: ${response.data['message']}';
        notifyListeners();
        return;
      }

      _qrUrl = response.data['data']['url'];
      _qrcodeKey = response.data['data']['qrcode_key'];
      _state = AuthState.qrReady;
      notifyListeners();

      _startPolling();
    } catch (e) {
      _state = AuthState.error;
      if (e is DioException) {
        if (e.message?.contains('XMLHttpRequest') == true) {
          _errorMessage = '网络请求被阻止（Web 平台不支持，请使用 Windows/Android）';
        } else {
          _errorMessage = '网络连接失败，请检查网络后重试';
        }
      } else {
        _errorMessage = '发生未知错误: $e';
      }
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollLoginStatus(),
    );
  }

  Future<void> _pollLoginStatus() async {
    if (_qrcodeKey == null) return;

    try {
      final response = await _dio.get(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
        queryParameters: {'qrcode_key': _qrcodeKey},
      );

      final data = response.data['data'];
      final code = data['code'];

      if (code == 0) {
        // Login successful
        _pollTimer?.cancel();

        final url = Uri.parse(data['url']);
        final sessdata = url.queryParameters['SESSDATA'] ?? '';
        final biliJct = url.queryParameters['bili_jct'] ?? '';
        final dedeUserId = url.queryParameters['DedeUserID'] ?? '';
        final refreshToken = data['refresh_token'] ?? '';

        await _storage.saveAuth(
          sessdata: sessdata,
          biliJct: biliJct,
          userId: dedeUserId,
          refreshToken: refreshToken,
        );

        // Fetch user profile via public API (no auth needed)
        try {
          final userResp = await _dio.get(
            'https://api.bilibili.com/x/web-interface/card',
            queryParameters: {'mid': dedeUserId, 'photo': false},
          );
          if (userResp.data['code'] == 0) {
            final card = userResp.data['data']['card'];
            await _storage.saveAuth(
              sessdata: sessdata,
              biliJct: biliJct,
              userId: dedeUserId,
              refreshToken: refreshToken,
              userName: card['name'],
              userFace: card['face'],
            );
          }
        } catch (_) {}

        _state = AuthState.loggedIn;
        notifyListeners();
      } else if (code == 86090) {
        if (_state != AuthState.scanned) {
          _state = AuthState.scanned;
          notifyListeners();
        }
      } else if (code == 86038) {
        _pollTimer?.cancel();
        _state = AuthState.error;
        _errorMessage = '二维码已过期，请重新生成';
        notifyListeners();
      }
      // 86101 = not scanned yet → keep polling
    } catch (_) {
      // Network hiccup, keep polling
    }
  }

  Future<void> enterAppReviewMode({
    required String userId,
    required String userName,
    String? userFace,
  }) async {
    _pollTimer?.cancel();
    await _storage.saveAuth(
      sessdata: 'app-review-demo',
      biliJct: 'app-review-demo',
      userId: userId,
      refreshToken: 'app-review-demo',
      userName: userName,
      userFace: userFace,
    );
    await _storage.setAppReviewMode(true);
    _state = AuthState.loggedIn;
    _qrUrl = null;
    _qrcodeKey = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _pollTimer?.cancel();
    await _storage.setAppReviewMode(false);
    await _storage.clearAuth();
    _state = AuthState.notLoggedIn;
    _qrUrl = null;
    _qrcodeKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
