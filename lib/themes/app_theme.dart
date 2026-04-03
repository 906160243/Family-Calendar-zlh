import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Colors
  static const Color background = Color(0xFFFCFBF8);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color pageBackground = Color(0xFFF8F7F6);
  static const Color headerBackground = cardBackground;
  static const Color headline = Color(0xFF0F172A);
  static const Color accent = Color(0xFFFAC638);
  static const Color secondaryAccent = Color(0xFFFDE047);
  static const Color accentDark = Color(0xFFF59E0B);
  static const Color border = Color.fromRGBO(255, 255, 255, 0.2);
  static const Color mutedText = Color(0xFF64748B);
  static const Color inactiveIcon = Color(0xFF94A3B8);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color error = Color(0xFFEF4444);
  static const Color lightBackground = Color(0xFFF3EEE0);
  static const Color familyMemberCountColor = Color(0xFFE2B736);

  // Text styles
  static const TextStyle headlineStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: headline,
    letterSpacing: -0.5,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: headline,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: headline,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: mutedText,
  );

  static const TextStyle buttonStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: Colors.black87,
  );

  static const TextStyle familyNameStyle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: headline,
  );

  static const TextStyle familyMemberCountStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: familyMemberCountColor,
  );

  static const TextStyle navLabelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: inactiveIcon,
  );

  static const TextStyle navLabelSelectedStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: accent,
  );

  // Shadows
  static const BoxShadow cardShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.05),
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  static const BoxShadow headerShadow = BoxShadow(
    color: Color.fromRGBO(15, 23, 42, 0.03),
    blurRadius: 6,
    offset: Offset(0, 1),
  );

  static const BoxShadow backButtonShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.06),
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  static const SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: headerBackground,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: headerBackground,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: headerBackground,
  );

  // Radius
  static const double borderRadius = 24.0;
  static const double smallBorderRadius = 16.0;

  // Spacing
  static const double headerHeight = 68.0;
  static const double bottomNavHeight = 94.0;
  static const double horizontalPadding = 24.0;
  static const double verticalPadding = 12.0;

  // Blur
  static const double blurSigma = 6.0;

  // Back button
  static const Color backButtonBackground = Colors.white;
  static const Color backButtonIconColor = Color(0xFF0F172A);
  static const double backButtonSize = 40;
  static const double backButtonIconSize = 18;

  static Widget backButton(BuildContext context, {VoidCallback? onPressed}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed ?? () => Navigator.of(context).pop(),
      child: Container(
        width: backButtonSize,
        height: backButtonSize,
        decoration: BoxDecoration(
          color: backButtonBackground,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [backButtonShadow],
        ),
        child: const Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            size: backButtonIconSize,
            color: backButtonIconColor,
          ),
        ),
      ),
    );
  }
}
