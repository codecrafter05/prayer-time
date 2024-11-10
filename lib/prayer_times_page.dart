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
  String? combinedDate; // التاريخ المدمج
  Duration? timeUntilNextPrayer;
  String? nextPrayerName;
  Timer? countdownTimer;
  String? dailyVerse; // آية القرآن اليومية

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
    loadDailyVerse(); // تحميل الآية اليومية
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

        String todayDay = today['day_of_week'];
        String hijriDay = today['hijri_day'].toString();
        String hijriMonth = today['hijri_month_name'];
        String hijriYear = today['hijri_year'].toString();

        String gregorianDay = today['gregorian_day'].toString();
        String gregorianMonth = today['gregorian_month'];
        String gregorianYear = today['gregorian_year'].toString();

        // إنشاء التاريخ المدمج
        combinedDate =
            '$todayDay $hijriDay $hijriMonth $hijriYear - $gregorianDay $gregorianMonth $gregorianYear';
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

    return '${adjustedHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period';
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

      // إذا لم يتم العثور على الصلاة التالية، تعيين العد التنازلي للفجر
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
        // إعادة حساب الوقت حتى الصلاة التالية وإعادة تشغيل العد
        calculateTimeUntilNextPrayer();
        startCountdown();
      }
    });
  }

  Future<void> loadDailyVerse() async {
    String jsonString = await rootBundle.loadString('assets/quran.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);

    List<dynamic> verses = jsonData["Sheet 3"];

    // حساب اليوم من السنة
    int dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays +
            1;

    int verseIndex = dayOfYear % verses.length;

    String verse = verses[verseIndex].values.first;

    setState(() {
      dailyVerse = verse;
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
            SizedBox(height: AppStyles.verticalSpacing / 2),
            Container(
              padding: AppStyles.headerPadding,
              child: Center(
                child: Text(
                  'مسجد الشيخ براهيم - الديه',
                  style: AppStyles.headerTextStyle,
                ),
              ),
            ),
            SizedBox(height: AppStyles.verticalSpacing),
            // عرض التاريخ المدمج في سطر واحد
            if (combinedDate != null)
              Text(
                combinedDate!,
                style: AppStyles.dateTextStyle,
                textAlign: TextAlign.center,
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
                  DateFormat('hh:mm:ss a').format(DateTime.now()),
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
                      width: 250.0, // زيادة العرض
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

            // عرض الآية القرآنية تحت الساعة الزمنية
            if (dailyVerse != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  dailyVerse!,
                  style: AppStyles.quranVerseTextStyle,
                  textAlign: TextAlign.center,
                ),
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
