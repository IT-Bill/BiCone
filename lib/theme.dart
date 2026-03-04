import 'package:flutter/cupertino.dart';

class AppTheme {
  static const Color biliPink = Color(0xFFFB7299);
  static const Color biliBlue = Color(0xFF00A1D6);

  static CupertinoThemeData get lightTheme {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: biliPink,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      barBackgroundColor: CupertinoColors.systemBackground,
      textTheme: CupertinoTextThemeData(
        navTitleTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: CupertinoColors.label,
        ),
      ),
    );
  }

  static CupertinoThemeData get darkTheme {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: biliPink,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      barBackgroundColor: CupertinoColors.systemBackground,
      textTheme: CupertinoTextThemeData(
        navTitleTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: CupertinoColors.label,
        ),
      ),
    );
  }
}
