import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'styles.dart';
import 'prayer_time_row.dart';

class PrayerTimesPage extends StatefulWidget {
  @override
  _PrayerTimesPageState createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  Map<String, dynamic>? todayData;
  String? todayDate;
  String? todayDay;
  String? hijriDate;
  Duration? timeUntilNextPrayer;
  String? nextPrayerName;
  Timer? countdownTimer;

  // قواميس الترجمة من الإنجليزية إلى العربية
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

    // ترجمة الشهر واليوم من الإنجليزية إلى العربية
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
        todayDate = '$currentDay $currentMonth $currentYear';
        todayDay = today['day_of_week'];
        hijriDate = '${today['hijri_month_name']} ${today['hijri_year']}';
      });
    }
  }

  void calculateTimeUntilNextPrayer() {
    if (todayData != null) {
      List<String> prayerTimes = [
        '${todayData!['fajr_hour'].toString()}:${todayData!['fajr_minute'].toString()}',
        '${todayData!['sunrise_hour'].toString()}:${todayData!['sunrise_minute'].toString()}',
        '${todayData!['dhuhr_hour'].toString()}:${todayData!['dhuhr_minute'].toString()}',
        '${todayData!['maghrib_hour'].toString()}:${todayData!['maghrib_minute'].toString()}',
      ];
      List<String> prayerNames = [
        'الفجر',
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

      // إذا لم يتم العثور على صلاة قادمة لهذا اليوم، اضبط العد التنازلي لصلاة الفجر في اليوم التالي
      if (!foundNextPrayer) {
        DateTime nextFajrTime = DateTime(
          now.year,
          now.month,
          now.day + 1,
          int.parse(prayerTimes[0].split(':')[0]),
          int.parse(prayerTimes[0].split(':')[1]),
        );
        setState(() {
          timeUntilNextPrayer = nextFajrTime.difference(now);
          nextPrayerName = prayerNames[0]; // الفجر
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
        // إعادة حساب الوقت للصلاة التالية والبدء من جديد
        calculateTimeUntilNextPrayer();
        startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      appBar: AppBar(
        title: Text('مواقيت الصلاة'),
        backgroundColor: AppStyles.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.red,
              child: Center(
                child: Text(
                  'مسجد الشيخ براهيم',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              '${todayDay ?? ''} - $todayDate',
              style: AppStyles.dateTextStyle,
            ),
            Text(
              'الهجري: $hijriDate',
              style: AppStyles.hijriDateTextStyle,
            ),
            if (todayData?['event'] != null)
              Text(
                'المناسبة: ${todayData!['event']}',
                style: AppStyles.eventTextStyle,
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 20),
            Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: AppStyles.timeTextStyle,
            ),
            if (timeUntilNextPrayer != null)
              Column(
                children: [
                  Text(
                    'الوقت المتبقي حتى ${nextPrayerName ?? ''}',
                    style: AppStyles.nextPrayerTextStyle,
                  ),
                  Text(
                    '${timeUntilNextPrayer!.inHours.toString().padLeft(2, '0')}:${(timeUntilNextPrayer!.inMinutes % 60).toString().padLeft(2, '0')}:${(timeUntilNextPrayer!.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            Divider(color: Colors.white54),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PrayerTimeColumn(
                    prayer: 'المغرب',
                    hour: todayData?['maghrib_hour']?.toString() ?? '',
                    minute: todayData?['maghrib_minute']?.toString() ?? ''),
                PrayerTimeColumn(
                    prayer: 'الظهر',
                    hour: todayData?['dhuhr_hour']?.toString() ?? '',
                    minute: todayData?['dhuhr_minute']?.toString() ?? ''),
                PrayerTimeColumn(
                    prayer: 'الشروق',
                    hour: todayData?['sunrise_hour']?.toString() ?? '',
                    minute: todayData?['sunrise_minute']?.toString() ?? ''),
                PrayerTimeColumn(
                    prayer: 'الفجر',
                    hour: todayData?['fajr_hour']?.toString() ?? '',
                    minute: todayData?['fajr_minute']?.toString() ?? ''),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
