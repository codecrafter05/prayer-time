import 'package:flutter/material.dart';
import 'prayer_times_page.dart';
import 'styles.dart'; // Import AppStyles

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor:
            AppStyles.backgroundColor, // Set app-wide background color
        useMaterial3: true,
      ),
      home: PrayerTimesPage(),
    );
  }
}
