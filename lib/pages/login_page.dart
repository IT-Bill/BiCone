import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primaryContainer, cs.surface],
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
                        MaterialPageRoute(builder: (_) => const HomePage()),
                      );
                    });
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.pets, size: 48, color: cs.onPrimary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Squirrel',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bilibili 视频自动监控下载',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 48),

                      // ── QR Card ──
                      Card(
                        elevation: 8,
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Text(
                                '扫码登录',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '请使用 Bilibili 手机客户端扫描二维码',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
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
                                    color: cs.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber,
                                          color: cs.onErrorContainer),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '当前运行在 Web 平台，Bilibili API 不支持浏览器跨域请求。\n请使用 Windows 或 Android 运行此应用。',
                                          style: TextStyle(
                                            color: cs.onErrorContainer,
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
          child: Center(child: CircularProgressIndicator()),
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
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.green[400]),
                    const SizedBox(height: 8),
                    const Text('已扫码，请在手机上确认'),
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
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.read<AuthService>().generateQRCode(),
                icon: const Icon(Icons.refresh),
                label: const Text('重新生成'),
              ),
            ],
          ),
        );

      default:
        return const SizedBox(
          width: 200,
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
    }
  }

  Widget _buildStatusText(AuthService auth) {
    final cs = Theme.of(context).colorScheme;

    switch (auth.state) {
      case AuthState.generatingQr:
        return const Text('正在生成二维码...');
      case AuthState.qrReady:
        return Text('等待扫码...', style: TextStyle(color: cs.primary));
      case AuthState.scanned:
        return Text('已扫码，请在手机上确认登录',
            style: TextStyle(color: Colors.green[700]));
      case AuthState.error:
        return Text(auth.errorMessage ?? '发生错误',
            style: TextStyle(color: cs.error));
      case AuthState.loggedIn:
        return Text('登录成功！', style: TextStyle(color: Colors.green[700]));
      default:
        return const SizedBox.shrink();
    }
  }
}
