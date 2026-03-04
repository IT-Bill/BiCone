import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().generateQRCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFCE4EC), // light pink
              CupertinoColors.systemGroupedBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Consumer<AuthService>(
                builder: (context, auth, _) {
                  // Auto-navigate on login
                  if (auth.state == AuthState.loggedIn) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.of(context).pushReplacement(
                        CupertinoPageRoute(
                            builder: (_) => const HomePage()),
                      );
                    });
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppTheme.biliPink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.paw,
                            size: 48, color: CupertinoColors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Squirrel',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.biliPink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bilibili 视频自动监控下载',
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ── QR Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemGrey
                                  .withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '扫码登录',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '请使用 Bilibili 手机客户端扫描二维码',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildQRContent(auth),
                            const SizedBox(height: 16),
                            _buildStatusText(auth),
                            if (kIsWeb) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3CD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons
                                          .exclamationmark_triangle,
                                      color: Color(0xFF856404),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '当前运行在 Web 平台，Bilibili API 不支持浏览器跨域请求。\n请使用 Windows 或 Android 运行此应用。',
                                        style: TextStyle(
                                          color: Color(0xFF856404),
                                          fontSize: 12,
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
                    ],
                  );
                },
              ),
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
                  color: const Color(0xFFFFFFFF).withOpacity(0.9),
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
