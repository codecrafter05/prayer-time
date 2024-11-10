// styles.dart

import 'package:flutter/material.dart';

class AppStyles {
  // الألوان
  static const Color backgroundColor =
      Color.fromARGB(255, 57, 96, 121); // لون الخلفية
  static const Color primaryTextColor = Colors.white;
  static const Color secondaryTextColor = Colors.white70;
  static const Color accentTextColor =
      Color.fromARGB(255, 199, 170, 3); // لون ذهبي للنص المميز
  static const Color dividerColor = Colors.white54;

  // الحشوات والتباعد
  static const EdgeInsets pagePadding = EdgeInsets.all(32.0);
  static const EdgeInsets headerPadding = EdgeInsets.all(24.0);
  static const double verticalSpacing = 40.0;
  static const double prayerTimeSpacing = 16.0;

  // أنماط النصوص
  static const TextStyle headerTextStyle = TextStyle(
    fontSize: 30,
    color: primaryTextColor,
    fontWeight: FontWeight.bold,
    fontFamily: 'Arabic',
  );

  static const TextStyle dateTextStyle = TextStyle(
    fontSize: 36,
    color: primaryTextColor,
    fontFamily: 'Arabic',
  );

  static const TextStyle hijriDateTextStyle = TextStyle(
    fontSize: 32,
    color: secondaryTextColor,
    fontFamily: 'Arabic',
  );

  static const TextStyle eventTextStyle = TextStyle(
    fontSize: 28,
    color: Colors.orange,
    fontFamily: 'Arabic',
  );

  static const TextStyle timeTextStyle = TextStyle(
    fontSize: 80,
    color: accentTextColor,
    fontWeight: FontWeight.bold,
    fontFamily: 'Digital',
  );

  static const TextStyle nextPrayerLabelTextStyle = TextStyle(
    fontSize: 24,
    color: secondaryTextColor,
    fontFamily: 'Arabic',
  );

  static const TextStyle countdownTextStyle = TextStyle(
    fontSize: 40,
    color: accentTextColor,
    fontWeight: FontWeight.bold,
    fontFamily: 'Digital',
  );

  static const TextStyle prayerNameTextStyle = TextStyle(
    fontSize: 40,
    color: primaryTextColor,
    fontFamily: 'Arabic',
  );

  static const TextStyle prayerTimeTextStyle = TextStyle(
    fontSize: 36,
    color: secondaryTextColor,
    fontFamily: 'Digital',
  );

  static const TextStyle footerTextStyle = TextStyle(
    fontSize: 28,
    color: primaryTextColor,
    fontFamily: 'Arabic',
  );

  // نمط نص الآية القرآنية
  static const TextStyle quranVerseTextStyle = TextStyle(
    fontSize: 28,
    color: Colors.white,
    fontFamily: 'Arabic',
  );
  static const TextStyle largeHeaderTextStyle = TextStyle(
    fontSize: 100, // حجم خط أكبر
    color: primaryTextColor,
    fontWeight: FontWeight.bold,
    fontFamily: 'Arabic',
  );
}
