// prayer_times_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'styles.dart'; // استيراد ملف الأنماط

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

  // تحويل الأشهر والأيام من الإنجليزية إلى العربية
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

    // تحويل الشهر واليوم من الإنجليزية إلى العربية
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

    // تحديد AM/PM بناءً على الصلاة والساعة
    if (prayer == 'الفجر' || prayer == 'الشروق') {
      isPM = false; // دائماً صباحاً للفجر والشروق
    } else if (prayer == 'الظهر') {
      isPM = hour >= 12; // مساءً إذا كانت الساعة 12 أو أكثر
    } else {
      isPM = true; // المغرب دائماً مساءً
    }

    // تحويل إلى صيغة 12 ساعة
    int adjustedHour = hour % 12 == 0 ? 12 : hour % 12;
    String period = isPM ? 'م' : 'ص';

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

      // إذا لم يتم العثور على الصلاة التالية، تعيين العد التنازلي للفجر في اليوم التالي
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
        // إعادة حساب الوقت حتى الصلاة التالية وإعادة تشغيل العد التنازلي
        calculateTimeUntilNextPrayer();
        startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // للحصول على عرض الشاشة
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      body: Padding(
        padding: AppStyles.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: AppStyles.headerPadding,
              child: Center(
                child: Text(
                  'مسجد الشيخ براهيم',
                  style: AppStyles.headerTextStyle,
                ),
              ),
            ),
            SizedBox(height: AppStyles.verticalSpacing),
            Text(
              '${todayDay ?? ''} - ${todayDate ?? ''}',
              style: AppStyles.dateTextStyle,
            ),
            Text(
              ' ${hijriDate ?? ''}',
              style: AppStyles.hijriDateTextStyle,
            ),
            if (todayData?['event'] != null)
              Text(
                'المناسبة: ${todayData!['event']}',
                style: AppStyles.eventTextStyle,
                textAlign: TextAlign.center,
              ),
            SizedBox(height: AppStyles.verticalSpacing),

            // تعديل عرض الساعة الزمنية والعد التنازلي داخل Stack
            Stack(
              alignment: Alignment.center,
              children: [
                // عرض الوقت باللغة الإنجليزية في المركز
                Text(
                  DateFormat('hh:mm a').format(DateTime.now()),
                  style: AppStyles.timeTextStyle,
                ),
                // استخدام Transform.translate لتحريك الشعار
                Transform.translate(
                  offset:
                      Offset(-600.0, 0), // (x, y) قم بتعديل القيمة x حسب الحاجة
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 200,
                  ),
                ),
                // إضافة العد التنازلي داخل دائرة وتحريكه إلى اليمين
                if (timeUntilNextPrayer != null)
                  Transform.translate(
                    offset: Offset(
                        600.0, 0), // (x, y) قم بتعديل القيمة x حسب الحاجة
                    child: Container(
                      width: 250.0, // زيادة العرضr
                      height: 250.0, // زيادة الارتفاع
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24, // لون الخلفية للدائرة
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // إضافة هذا السطر
                          children: [
                            Text(
                              '${timeUntilNextPrayer!.inHours.toString().padLeft(2, '0')}:${(timeUntilNextPrayer!.inMinutes % 60).toString().padLeft(2, '0')}:${(timeUntilNextPrayer!.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: AppStyles.countdownTextStyle,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              '${nextPrayerName ?? ''}',
                              style: AppStyles.nextPrayerLabelTextStyle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Divider(color: AppStyles.dividerColor, thickness: 2),
            SizedBox(height: AppStyles.verticalSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PrayerTimeColumn(
                  prayer: 'الفجر',
                  time: formatTimeWithPeriod(
                    int.parse(todayData?['fajr_hour'].toString() ?? '5'),
                    int.parse(todayData?['fajr_minute'].toString() ?? '0'),
                    prayer: 'الفجر',
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
                  prayer: 'الظهر',
                  time: formatTimeWithPeriod(
                    int.parse(todayData?['dhuhr_hour'].toString() ?? '12'),
                    int.parse(todayData?['dhuhr_minute'].toString() ?? '0'),
                    prayer: 'الظهر',
                  ),
                ),
                PrayerTimeColumn(
                  prayer: 'المغرب',
                  time: formatTimeWithPeriod(
                    int.parse(todayData?['maghrib_hour'].toString() ?? '5'),
                    int.parse(todayData?['maghrib_minute'].toString() ?? '0'),
                    prayer: 'المغرب',
                  ),
                ),
              ],
            ),
            // إضافة Spacer لدفع النص إلى الأسفل
            Expanded(
              child: SizedBox(),
            ),
            // إضافة الجملة في الفوتر
            Center(
              child: Text(
                'سُبْحَانَ اللّهِ وَ بِحَمْدِهِ سُبْحَانَ اللّهِ الْعَظِيم',
                style: AppStyles.footerTextStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// مكون PrayerTimeColumn لعرض وقت الصلاة
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
          style: AppStyles.prayerNameTextStyle,
        ),
        SizedBox(height: AppStyles.prayerTimeSpacing),
        Text(
          time,
          style: AppStyles.prayerTimeTextStyle,
        ),
      ],
    );
  }
}
