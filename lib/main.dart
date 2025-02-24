import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_page.dart';
import 'prayer_times_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final didSeeWelcome = prefs.getBool('didSeeWelcome') ?? false;
  final chosenMosque = prefs.getString('chosenMosque') ?? 'مسجد افتراضي';

  runApp(MyApp(
    didSeeWelcome: didSeeWelcome,
    chosenMosque: chosenMosque,
  ));
}

class MyApp extends StatelessWidget {
  final bool didSeeWelcome;
  final String chosenMosque;
  const MyApp({
    Key? key,
    required this.didSeeWelcome,
    required this.chosenMosque,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Time App',
      home: didSeeWelcome
          ? PrayerTimesPage(mosqueName: chosenMosque)
          : WelcomePage(),
    );
  }
}
