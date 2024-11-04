import 'package:flutter/material.dart';

class AppStyles {
  static const Color backgroundColor = Colors.blueGrey;
  static const Color primaryTextColor = Colors.white;
  static const Color secondaryTextColor = Colors.white70;
  static const Color accentTextColor = Colors.amber;

  static const TextStyle dateTextStyle = TextStyle(
    fontSize: 24,
    color: primaryTextColor,
  );

  static const TextStyle hijriDateTextStyle = TextStyle(
    fontSize: 20,
    color: secondaryTextColor,
  );

  static const TextStyle eventTextStyle = TextStyle(
    fontSize: 18,
    color: Colors.lightBlueAccent,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle timeTextStyle = TextStyle(
    fontSize: 50,
    color: primaryTextColor,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle nextPrayerTextStyle = TextStyle(
    fontSize: 18,
    color: accentTextColor,
  );

  static const TextStyle prayerRowTextStyle = TextStyle(
    fontSize: 22,
    color: primaryTextColor,
  );
}
