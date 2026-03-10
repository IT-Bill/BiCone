import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

enum UpdateSource { github, gitee }

class ReleaseInfo {
  final String version;
  final String changelog;
  final String downloadUrl;

  ReleaseInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
  });
}

class UpdateService {
  static const _githubRepo = 'IT-Bill/BiCone';

  static const _installChannel =
      MethodChannel('cn.itbill.bicone/install_permission');

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Get current app version string.
  static Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Fetch the latest release info from the chosen source.
  static Future<ReleaseInfo?> checkForUpdate(UpdateSource source) async {
    try {
      final url = switch (source) {
        UpdateSource.github =>
          'https://api.github.com/repos/$_githubRepo/releases/latest',
        UpdateSource.gitee =>
          'https://gitee.com/api/v5/repos/$_githubRepo/releases/latest',
      };

      final resp = await _dio.get<Map<String, dynamic>>(url);
      final data = resp.data;
      if (data == null) return null;

      final tagName = (data['tag_name'] as String?) ?? '';
      final remoteVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final body = (data['body'] as String?) ?? '';

      // Determine download URL based on platform + architecture
      final downloadUrl = _resolveDownloadUrl(data, source, remoteVersion);
      if (downloadUrl == null) return null;

      return ReleaseInfo(
        version: remoteVersion,
        changelog: body,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  /// Compare two semver strings. Returns true if remote > current.
  static bool isNewer(String current, String remote) {
    final cur = current.split('.').map(int.tryParse).toList();
    final rem = remote.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final c = (i < cur.length ? cur[i] : 0) ?? 0;
      final r = (i < rem.length ? rem[i] : 0) ?? 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Download APK/installer and return the local file path.
  static Future<String> downloadUpdate(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = url.split('/').last;
    final savePath = '${dir.path}/$fileName';

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );

    return savePath;
  }

  /// Check if the app has permission to install packages (Android 8+).
  static Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _installChannel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Request install permission. Returns true if granted after user action.
  static Future<bool> requestInstallPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _installChannel.invokeMethod<bool>('requestInstallPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Install the downloaded APK (Android) or open the installer (Windows).
  static Future<void> installUpdate(String filePath) async {
    if (Platform.isAndroid) {
      final canInstall = await canInstallPackages();
      if (!canInstall) {
        throw Exception('安装权限未授予，请在设置中允许安装未知应用');
      }
    }
    await OpenFilex.open(filePath);
  }

  static String? _resolveDownloadUrl(
    Map<String, dynamic> data,
    UpdateSource source,
    String version,
  ) {
    if (Platform.isAndroid) {
      final arch = _getAndroidArch();
      final expectedName = 'BiCone-$version-$arch.apk';
      return _findAssetUrl(data, expectedName, source, version);
    } else if (Platform.isWindows) {
      final expectedName = 'BiCone-$version-windows-x64-setup.exe';
      return _findAssetUrl(data, expectedName, source, version);
    }
    return null;
  }

  static String? _findAssetUrl(
    Map<String, dynamic> data,
    String expectedName,
    UpdateSource source,
    String version,
  ) {
    final assets = data['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name == expectedName) {
          return (asset['browser_download_url'] as String?) ?? '';
        }
      }
    }
    // Fallback: construct URL directly
    if (source == UpdateSource.github) {
      return 'https://github.com/$_githubRepo/releases/download/v$version/$expectedName';
    } else {
      return 'https://gitee.com/$_githubRepo/releases/download/v$version/$expectedName';
    }
  }

  static String _getAndroidArch() {
    // dart:io doesn't expose ABI directly; use supported ABIs heuristic
    // On 64-bit devices (majority), use arm64-v8a
    // Process.run to get the ABI would be complex; default to arm64
    return 'arm64-v8a';
  }
}
