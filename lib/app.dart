import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

class SquirrelApp extends StatelessWidget {
  const SquirrelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Squirrel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
