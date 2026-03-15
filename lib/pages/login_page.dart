import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/demo_service.dart';
import '../services/download_service.dart';
import '../services/error_report_utils.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isEnteringAppReviewDemo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().generateQRCode();
    });
  }

  Future<void> _enterAppReviewDemo() async {
    if (_isEnteringAppReviewDemo) return;

    setState(() {
      _isEnteringAppReviewDemo = true;
    });

    final storage = context.read<StorageService>();
    final auth = context.read<AuthService>();
    final downloadService = context.read<DownloadService>();
    final navigator = Navigator.of(context, rootNavigator: true);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(radius: 16),
      ),
    );

    try {
      await DemoService.seedAppReviewDemo(
        storage: storage,
        auth: auth,
      );
      await downloadService.hydrateAppReviewDemoTasks();
    } finally {
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
      if (mounted) {
        setState(() {
          _isEnteringAppReviewDemo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Consumer<AuthService>(
              builder: (context, auth, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Logo ──
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.biliPink.withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'BiCone',
                      style: TextStyle(
                        fontSize: 36,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.biliPink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bilibili 视频自动缓存',
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 56),

                    // ── QR Card ──
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground.resolveFrom(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: CupertinoColors.systemGrey5.resolveFrom(context),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '扫码登录',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请使用 Bilibili 手机客户端扫描二维码',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildQRContent(auth),
                          const SizedBox(height: 24),
                          _buildStatusText(auth),
                          if (kIsWeb) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.exclamationmark_triangle,
                                    color: Color(0xFF856404),
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '当前运行在 Web 平台，Bilibili API 不支持浏览器跨域请求。\n请使用 Windows 或 Android 运行此应用。',
                                      style: TextStyle(
                                        color: Color(0xFF856404),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          onPressed:
                              _isEnteringAppReviewDemo ? null : _enterAppReviewDemo,
                          child: const Column(
                            children: [
                              Text(
                                'App Review Demo',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '供 TestFlight / App Review 使用，自动载入演示账号与样例数据',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRContent(AuthService auth) {
    switch (auth.state) {
      case AuthState.generatingQr:
        return const SizedBox(
          width: 200,
          height: 200,
          child: Center(child: CupertinoActivityIndicator(radius: 16)),
        );

      case AuthState.qrReady:
      case AuthState.scanned:
        return Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: auth.qrUrl!,
              version: QrVersions.auto,
              size: 200,
            ),
            if (auth.state == AuthState.scanned)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.checkmark_circle_fill,
                        size: 48, color: CupertinoColors.activeGreen),
                    SizedBox(height: 8),
                    Text('已扫码，请在手机上确认'),
                  ],
                ),
              ),
          ],
        );

      case AuthState.error:
        return SizedBox(
          width: 200,
          height: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle,
                  size: 48, color: CupertinoColors.destructiveRed),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () =>
                    context.read<AuthService>().generateQRCode(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.refresh, size: 18),
                    SizedBox(width: 6),
                    Text('重新生成'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  final auth = context.read<AuthService>();
                  reportErrorToSentry(
                    context,
                    auth.errorMessage ?? '登录错误',
                    detail: '登录二维码生成失败',
                  );
                },
                child: const Text('反馈', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );

      default:
        return const SizedBox(
          width: 200,
          height: 200,
          child: Center(child: CupertinoActivityIndicator(radius: 16)),
        );
    }
  }

  Widget _buildStatusText(AuthService auth) {
    switch (auth.state) {
      case AuthState.generatingQr:
        return const Text('正在生成二维码...');
      case AuthState.qrReady:
        return const Text('等待扫码...',
            style: TextStyle(color: AppTheme.biliPink));
      case AuthState.scanned:
        return const Text('已扫码，请在手机上确认登录',
            style: TextStyle(color: CupertinoColors.activeGreen));
      case AuthState.error:
        return Text(auth.errorMessage ?? '发生错误',
            style:
                const TextStyle(color: CupertinoColors.destructiveRed));
      case AuthState.loggedIn:
        return const Text('登录成功！',
            style: TextStyle(color: CupertinoColors.activeGreen));
      default:
        return const SizedBox.shrink();
    }
  }
}
