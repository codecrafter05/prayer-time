// prayertime/lib/styles.dart

import 'package:flutter/material.dart';

class AppStyles {
  static const Color backgroundColor = Color.fromARGB(255, 255, 255, 255);
  static const Color primaryTextColor = Colors.white;
  static const Color secondaryTextColor = Colors.white70;

  static const double prayerTimeSpacing = 16.0;

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
}
