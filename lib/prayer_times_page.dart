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

  @override
  void initState() {
    super.initState();
    loadPrayerTimes();
    calculateTimeUntilNextPrayer();
  }

  Future<void> loadPrayerTimes() async {
    String jsonString = await rootBundle.loadString('assets/prayer_times.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);

    int currentDay = DateTime.now().day;
    String currentMonth = DateFormat('MMMM').format(DateTime.now());
    int currentYear = DateTime.now().year;

    List<dynamic> sheetData = jsonData["Sheet 2"];

    var today = sheetData.firstWhere(
      (item) =>
          item['gregorian_day'] == currentDay &&
          item['gregorian_month'].toString().toLowerCase() ==
              currentMonth.toLowerCase() &&
          item['gregorian_year'] == currentYear,
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
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: Text('مواقيت الصلاة'),
        backgroundColor: Colors.blueGrey[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // التاريخ الميلادي والهجري
            Text(
              '${todayDay ?? ''} - $todayDate',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            Text(
              'الهجري: $hijriDate',
              style: TextStyle(fontSize: 20, color: Colors.white70),
            ),
            SizedBox(height: 8),
            // عرض المناسبة إذا كانت موجودة
            if (todayData?['event'] != null)
              Text(
                'المناسبة: ${todayData!['event']}',
                style: TextStyle(fontSize: 18, color: Colors.lightBlueAccent),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 20),
            // عرض الساعة الحالية
            Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: TextStyle(
                  fontSize: 50,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            // الوقت المتبقي للصلاة القادمة
            if (timeUntilNextPrayer != null)
              Text(
                'الوقت المتبقي حتى ${nextPrayerName ?? ''}: ${timeUntilNextPrayer!.inHours}:${(timeUntilNextPrayer!.inMinutes % 60).toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 18, color: Colors.amber),
              ),
            SizedBox(height: 30),
            Divider(color: Colors.white54),
            SizedBox(height: 10),
            // عرض أوقات الصلوات بشكل مستقيم بدون العصر والعشاء
            prayerTimeRow(
                'الفجر', todayData?['fajr_hour'], todayData?['fajr_minute']),
            prayerTimeRow('الشروق', todayData?['sunrise_hour'],
                todayData?['sunrise_minute']),
            prayerTimeRow(
                'الظهر', todayData?['dhuhr_hour'], todayData?['dhuhr_minute']),
            prayerTimeRow('المغرب', todayData?['maghrib_hour'],
                todayData?['maghrib_minute']),
          ],
        ),
      ),
    );
  }

  Widget prayerTimeRow(String prayer, dynamic hour, dynamic minute) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${hour.toString()}:${minute.toString()}',
          style: TextStyle(fontSize: 22, color: Colors.white),
        ),
        Text(
          prayer,
          style: TextStyle(fontSize: 22, color: Colors.white),
        ),
      ],
    );
  }
}
