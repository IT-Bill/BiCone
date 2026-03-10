import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import '../services/update_service.dart';

/// Show the full download-and-install flow for an app update.
///
/// Handles: install permission check (Android) → download with progress → install.
/// [onError] is called when an error occurs (e.g. download failure).
/// If [onError] is null, errors are silently ignored.
Future<void> showDownloadAndInstallDialog(
  BuildContext context,
  ReleaseInfo release, {
  void Function(BuildContext context, String title, String message)? onError,
}) async {
  // Check install permission on Android before downloading
  if (Platform.isAndroid) {
    final canInstall = await UpdateService.canInstallPackages();
    if (!canInstall) {
      if (!context.mounted) return;
      final proceed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('需要安装权限'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '由于本应用通过安装包直接更新（非应用商店），'
              'Android 系统要求授予「安装未知应用」权限。\n\n'
              '此权限仅用于应用更新，不会用于其他用途。',
              style: TextStyle(fontSize: 13),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('前往设置'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      final granted = await UpdateService.requestInstallPermission();
      if (!granted) {
        if (context.mounted && onError != null) {
          onError(context, '权限未授予', '未获得安装权限，无法更新应用。');
        }
        return;
      }
    }
  }

  if (!context.mounted) return;

  final cancelToken = CancelToken();
  final progressNotifier = ValueNotifier<String>('准备下载...');
  final valueNotifier = ValueNotifier<double?>(null);

  showCupertinoDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('正在下载更新'),
      content: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            ValueListenableBuilder<double?>(
              valueListenable: valueNotifier,
              builder: (_, value, _) => LinearProgressIndicator(value: value),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: progressNotifier,
              builder: (_, text, _) =>
                  Text(text, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () {
            cancelToken.cancel();
            Navigator.pop(ctx);
          },
          child: const Text('取消'),
        ),
      ],
    ),
  );

  try {
    final filePath = await UpdateService.downloadUpdate(
      release.downloadUrl,
      onProgress: (received, total) {
        if (total > 0) {
          valueNotifier.value = received / total;
          progressNotifier.value =
              '${(received / 1024 / 1024).toStringAsFixed(1)} / '
              '${(total / 1024 / 1024).toStringAsFixed(1)} MB';
        }
      },
      cancelToken: cancelToken,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss download dialog

    await UpdateService.installUpdate(filePath);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) return;
    if (context.mounted) {
      Navigator.pop(context);
      onError?.call(context, '下载失败', '下载更新包失败: $e');
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      onError?.call(context, '下载失败', '下载更新包失败: $e');
    }
  } finally {
    progressNotifier.dispose();
    valueNotifier.dispose();
  }
}
