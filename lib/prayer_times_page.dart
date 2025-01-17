import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

class PrayerTimesPage extends StatefulWidget {
  @override
  _PrayerTimesPageState createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  Map<String, dynamic>? todayData;
  String? combinedDate;
  Duration? timeUntilNextPrayer;
  String? nextPrayerName;
  Timer? countdownTimer;
  String? dailyVerse;

  final Map<String, String> englishToArabicMonths = {
    'January': 'يناير',
    'February': 'فبراير',
    'March': 'مارس',
    'April': 'أبريل',
    'May': 'مايو',
    'June': 'يونيو',
    'July': 'يوليو',
    'August': 'أغسطس',
    'September': 'سبتمبر',
    'October': 'أكتوبر',
    'November': 'نوفمبر',
    'December': 'ديسمبر',
  };

  final Map<String, String> englishToArabicDays = {
    'Sunday': 'الأحد',
    'Monday': 'الإثنين',
    'Tuesday': 'الثلاثاء',
    'Wednesday': 'الأربعاء',
    'Thursday': 'الخميس',
    'Friday': 'الجمعة',
    'Saturday': 'السبت',
  };

  @override
  void initState() {
    super.initState();
    loadPrayerTimes();
    calculateTimeUntilNextPrayer();
    startCountdown();
    loadDailyVerse();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> loadPrayerTimes() async {
    String jsonString = await rootBundle.loadString('assets/prayer_times.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);

    int currentDay = DateTime.now().day;
    String currentMonthEnglish = DateFormat('MMMM').format(DateTime.now());
    String currentDayOfWeekEnglish = DateFormat('EEEE').format(DateTime.now());
    int currentYear = DateTime.now().year;

    String currentMonth =
        englishToArabicMonths[currentMonthEnglish] ?? currentMonthEnglish;
    String currentDayOfWeek =
        englishToArabicDays[currentDayOfWeekEnglish] ?? currentDayOfWeekEnglish;

    List<dynamic> sheetData = jsonData["Sheet 2"];

    var today = sheetData.firstWhere(
      (item) =>
          item['gregorian_day'] == currentDay &&
          item['gregorian_month'] == currentMonth &&
          item['gregorian_year'] == currentYear &&
          item['day_of_week'] == currentDayOfWeek,
      orElse: () => null,
    );

    if (today != null) {
      setState(() {
        todayData = today;

        String todayDay = today['day_of_week'];
        String hijriDay = today['hijri_day'].toString();
        String hijriMonth = today['hijri_month_name'];
        String hijriYear = today['hijri_year'].toString();

        String gregorianDay = today['gregorian_day'].toString();
        String gregorianMonth = today['gregorian_month'];
        String gregorianYear = today['gregorian_year'].toString();

        combinedDate = '$todayDay $hijriDay $hijriMonth $hijriYear - '
            '$gregorianDay $gregorianMonth $gregorianYear';
      });
    }
  }

  Future<void> loadDailyVerse() async {
    String jsonString = await rootBundle.loadString('assets/quran.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);

    List<dynamic> verses = jsonData["Sheet 3"];

    int dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays +
            1;

    int verseIndex = dayOfYear % verses.length;

    String verse = verses[verseIndex].values.first;

    setState(() {
      dailyVerse = verse;
    });
  }

  void calculateTimeUntilNextPrayer() {
    if (todayData != null) {
      List<String> prayerTimes = [
        '${todayData!['fajr_hour']}:${todayData!['fajr_minute']}',
        '${todayData!['sunrise_hour']}:${todayData!['sunrise_minute']}',
        '${todayData!['dhuhr_hour']}:${todayData!['dhuhr_minute']}',
        '${todayData!['maghrib_hour']}:${todayData!['maghrib_minute']}',
      ];
      List<String> prayerNames = [
        'الصبح',
        'الشروق',
        'الظهر',
        'المغرب',
      ];

      DateTime now = DateTime.now();
      bool foundNextPrayer = false;

      for (int i = 0; i < prayerTimes.length; i++) {
        List<String> timeParts = prayerTimes[i].split(':');
        DateTime prayerTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        if (prayerTime.isAfter(now)) {
          setState(() {
            timeUntilNextPrayer = prayerTime.difference(now);
            nextPrayerName = prayerNames[i];
          });
          foundNextPrayer = true;
          break;
        }
      }

      if (!foundNextPrayer) {
        List<String> fajrTimeParts = prayerTimes[0].split(':');
        DateTime nextFajrTime = DateTime(
          now.year,
          now.month,
          now.day + 1,
          int.parse(fajrTimeParts[0]),
          int.parse(fajrTimeParts[1]),
        );
        setState(() {
          timeUntilNextPrayer = nextFajrTime.difference(now);
          nextPrayerName = prayerNames[0];
        });
      }
    }
  }

  void startCountdown() {
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timeUntilNextPrayer != null && timeUntilNextPrayer!.inSeconds > 0) {
        setState(() {
          timeUntilNextPrayer = timeUntilNextPrayer! - Duration(seconds: 1);
        });
      } else {
        timer.cancel();
        calculateTimeUntilNextPrayer();
        startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (combinedDate != null)
              Text(
                combinedDate!,
                textAlign: TextAlign.center,
              ),
            if (todayData?['event'] != null)
              Text(
                'المناسبة: ${todayData!['event']}',
                textAlign: TextAlign.center,
              ),
            if (nextPrayerName != null && timeUntilNextPrayer != null)
              Column(
                children: [
                  Text('الوقت المتبقي لصلاة $nextPrayerName'),
                  Text(
                    '${timeUntilNextPrayer!.inHours.toString().padLeft(2, '0')}:${(timeUntilNextPrayer!.inMinutes % 60).toString().padLeft(2, '0')}:${(timeUntilNextPrayer!.inSeconds % 60).toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            if (dailyVerse != null)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  dailyVerse!,
                  textAlign: TextAlign.center,
                ),
              ),
            if (todayData != null)
              Column(
                children: [
                  Text(
                      'الصبح: ${todayData!['fajr_hour']}:${todayData!['fajr_minute']}'),
                  Text(
                      'الشروق: ${todayData!['sunrise_hour']}:${todayData!['sunrise_minute']}'),
                  Text(
                      'الظهر: ${todayData!['dhuhr_hour']}:${todayData!['dhuhr_minute']}'),
                  Text(
                      'المغرب: ${todayData!['maghrib_hour']}:${todayData!['maghrib_minute']}'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
