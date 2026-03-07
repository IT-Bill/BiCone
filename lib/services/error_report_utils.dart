import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sends an error message to Sentry and shows a confirmation dialog.
Future<void> reportErrorToSentry(
  BuildContext context,
  String errorMessage, {
  String? detail,
}) async {
  await Sentry.captureMessage(
    errorMessage,
    level: SentryLevel.error,
    withScope: detail != null
        ? (scope) {
            scope.setTag('detail', detail);
          }
        : null,
  );
  if (!context.mounted) return;
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      content: const Text('已上报，感谢反馈！'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
