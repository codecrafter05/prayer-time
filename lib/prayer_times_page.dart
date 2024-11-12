// prayer_times_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui; // لإدارة الصور
import 'dart:math' as math; // للعمليات الرياضية
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

  ui.Image? clockImage; // لإدارة صورة الساعة

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
    loadClockImage(); // تحميل صورة الساعة

    // تحديث واجهة المستخدم كل ثانية لتحريك عقارب الساعة
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> loadClockImage() async {
    // تحميل الصورة من المسار المحدد
    final data = await rootBundle.load('assets/images/Clock.png');
    final bytes = data.buffer.asUint8List();
    final image = await decodeImageFromList(bytes);
    setState(() {
      clockImage = image;
    });
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
        combinedDate = '$todayDay $hijriDay $hijriMonth $hijriYear - '
            '$gregorianDay $gregorianMonth $gregorianYear';
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
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/qmt.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: AppStyles.pagePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // إضافة الجملة الجديدة بخط كبير فوق العنوان الحالي
              Text(
                'لجنة المسجد',
                style: AppStyles.largeHeaderTextStyle,
                textAlign: TextAlign.center,
              ),
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

              // تعديل عرض العد التنازلي والشعار داخل Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الشعار داخل دائرة مملوءة
                  Padding(
                    padding: EdgeInsets.only(left: 10.0),
                    child: Container(
                      width: 250.0,
                      height: 250.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/images/logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 250.0), // الحفاظ على نفس التباعد
                  // العد التنازلي مع العبارة داخل Column
                  Column(
                    children: [
                      // عرض العبارة: الوقت المتبقي لصلاة اسم الصلاة
                      if (nextPrayerName != null)
                        Text(
                          'الوقت المتبقي لصلاة $nextPrayerName',
                          style: AppStyles.nextPrayerLabelTextStyle,
                          textAlign: TextAlign.center,
                        ),
                      SizedBox(height: 8.0),
                      // عرض العد التنازلي
                      if (timeUntilNextPrayer != null)
                        Text(
                          '${timeUntilNextPrayer!.inHours.toString().padLeft(2, '0')}:'
                          '${(timeUntilNextPrayer!.inMinutes % 60).toString().padLeft(2, '0')}:'
                          '${(timeUntilNextPrayer!.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: AppStyles.countdownTextStyle,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                  SizedBox(width: 250.0), // الحفاظ على نفس التباعد
                  // الدائرة على اليمين مع صورة الساعة وعقارب متحركة
                  Padding(
                    padding: EdgeInsets.only(right: 10.0),
                    child: Container(
                      width: 250.0,
                      height: 250.0,
                      child: CustomPaint(
                        painter: ClockPainter(clockImage: clockImage),
                      ),
                    ),
                  ),
                ],
              ),

              // عرض الآية القرآنية تحت العد التنازلي
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

// ClockPainter لرسم عقارب الساعة المتحركة
class ClockPainter extends CustomPainter {
  final ui.Image? clockImage;

  ClockPainter({this.clockImage});

  @override
  void paint(Canvas canvas, Size size) {
    if (clockImage != null) {
      // رسم صورة الساعة داخل الدائرة
      Paint paint = Paint();
      Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.clipPath(Path()..addOval(rect));
      canvas.drawImageRect(
        clockImage!,
        Rect.fromLTWH(
            0, 0, clockImage!.width.toDouble(), clockImage!.height.toDouble()),
        rect,
        paint,
      );
    } else {
      // إذا لم يتم تحميل الصورة بعد، رسم دائرة فارغة
      Paint circlePaint = Paint()..color = Colors.white24;
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), size.width / 2, circlePaint);
    }

    // رسم عقارب الساعة
    DateTime now = DateTime.now();
    double centerX = size.width / 2;
    double centerY = size.height / 2;
    double radius = size.width / 2;

    // حساب الزوايا للعقارب
    double hourAngle = ((now.hour % 12) + now.minute / 60) * 30 * math.pi / 180;
    double minuteAngle = (now.minute + now.second / 60) * 6 * math.pi / 180;
    double secondAngle = now.second * 6 * math.pi / 180;

    // رسم عقرب الساعات
    Paint hourHandPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4;

    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(
        centerX + radius * 0.5 * math.sin(hourAngle),
        centerY - radius * 0.5 * math.cos(hourAngle),
      ),
      hourHandPaint,
    );

    // رسم عقرب الدقائق
    Paint minuteHandPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(
        centerX + radius * 0.7 * math.sin(minuteAngle),
        centerY - radius * 0.7 * math.cos(minuteAngle),
      ),
      minuteHandPaint,
    );

    // رسم عقرب الثواني
    Paint secondHandPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(
        centerX + radius * 0.9 * math.sin(secondAngle),
        centerY - radius * 0.9 * math.cos(secondAngle),
      ),
      secondHandPaint,
    );

    // رسم النقطة المركزية
    Paint centerDotPaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(centerX, centerY), 4, centerDotPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
