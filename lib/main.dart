import 'package:flutter/material.dart';
import 'prayer_times_page.dart';
import 'styles.dart'; // استيراد AppStyles

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Time App',
      theme: ThemeData(
        fontFamily: 'Almarai', // تعيين الخط الافتراضي للتطبيق
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor:
            AppStyles.backgroundColor, // تعيين لون الخلفية للتطبيق
        useMaterial3: true,
      ),
      home: PrayerTimesPage(),
    );
  }
}
