import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialScrollBehavior, Scrollbar;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

class _DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return Scrollbar(
        controller: details.controller,
        thumbVisibility: true,
        child: child,
      );
    }
    return child;
  }
}

class BiConeApp extends StatelessWidget {
  const BiConeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'BiCone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: _DesktopScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
      ],
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isLoggedIn) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}
