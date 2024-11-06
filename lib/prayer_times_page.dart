import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

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

  // Translation maps from English to Arabic
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

    // Translate month and day from English to Arabic
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

  String formatTimeWithPeriod(int hour, int minute, {required String prayer}) {
    bool isPM;

    // Determine AM/PM based on the prayer and hour
    if (prayer == 'الفجر' || prayer == 'الشروق') {
      isPM = false; // Always AM for Fajr and Sunrise
    } else if (prayer == 'الظهر') {
      isPM = hour >= 12; // PM if 12 or above, otherwise AM
    } else {
      isPM = true; // Maghrib is always PM
    }

    // Convert to 12-hour format
    int adjustedHour = hour % 12 == 0 ? 12 : hour % 12;
    String period = isPM ? 'PM' : 'AM';

    return '${adjustedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
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

      // If no next prayer found, set countdown to Fajr next day
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
          nextPrayerName = prayerNames[0]; // Fajr
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
        // Recalculate time until the next prayer and restart countdown
        calculateTimeUntilNextPrayer();
        startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: AppBar(
        title: Text('مواقيت الصلاة'),
        backgroundColor: Colors.red,
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
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              'الهجري: $hijriDate',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (todayData?['event'] != null)
              Text(
                'المناسبة: ${todayData!['event']}',
                style: TextStyle(color: Colors.orange, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 20),
            Text(
              DateFormat('hh:mm a').format(DateTime.now()),
              style: TextStyle(fontSize: 32, color: Colors.white),
            ),
            if (timeUntilNextPrayer != null)
              Column(
                children: [
                  Text(
                    'الوقت المتبقي حتى ${nextPrayerName ?? ''}',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
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
                  time: formatTimeWithPeriod(
                    int.parse(todayData?['maghrib_hour'].toString() ?? '5'),
                    int.parse(todayData?['maghrib_minute'].toString() ?? '0'),
                    prayer: 'المغرب',
                  ),
                ),
                PrayerTimeColumn(
                  prayer: 'الظهر',
                  time: formatTimeWithPeriod(
                    int.parse(todayData?['dhuhr_hour'].toString() ?? '12'),
                    int.parse(todayData?['dhuhr_minute'].toString() ?? '0'),
                    prayer: 'الظهر',
                  ),
                ),
                PrayerTimeColumn(
                  prayer: 'الشروق',
                  time: formatTimeWithPeriod(
                    int.parse(todayData?['sunrise_hour'].toString() ?? '6'),
                    int.parse(todayData?['sunrise_minute'].toString() ?? '0'),
                    prayer: 'الشروق',
                  ),
                ),
                PrayerTimeColumn(
                  prayer: 'الفجر',
                  time: formatTimeWithPeriod(
                    int.parse(todayData?['fajr_hour'].toString() ?? '5'),
                    int.parse(todayData?['fajr_minute'].toString() ?? '0'),
                    prayer: 'الفجر',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom widget for prayer time display
class PrayerTimeColumn extends StatelessWidget {
  final String prayer;
  final String time;

  PrayerTimeColumn({required this.prayer, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          prayer,
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }
}
