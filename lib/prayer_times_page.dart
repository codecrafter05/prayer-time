import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:prayertime/prayer_notification_page.dart';

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

  Duration? totalPrayerWindow;

  DateTime _currentTime = DateTime.now();

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
    loadDailyVerse();
    startCountdown();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  void startCountdown() {
    countdownTimer = Timer.periodic(Duration(minutes: 3), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });

      if (timeUntilNextPrayer != null && timeUntilNextPrayer!.inSeconds > 0) {
        setState(() {
          timeUntilNextPrayer = timeUntilNextPrayer! - Duration(seconds: 1);
        });
      } else {
        timer.cancel();

        // 1) الانتقال لصفحة الإشعار
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrayerNotificationPage(
                prayerName: nextPrayerName ?? "الصلاة",
              ),
            ),
          );

          // 2) بعد 5 دقائق، إغلاق صفحة الإشعار
          Future.delayed(Duration(seconds: 5), () {
            // تأكّد أولًا أننا ما زلنا داخل التطبيق ولم يُغلق أو يُغادر الصفحة
            if (mounted) {
              Navigator.pop(context);
            }

            // 3) بعد العودة، نحسب وقت الصلاة التالية ونشغّل المؤقِّت من جديد
            calculateTimeUntilNextPrayer();
            startCountdown();
          });
        });
      }
    });
  }

  // -------------------------------------------
  // تحميل بيانات أوقات الصلاة من ملف JSON
  // -------------------------------------------
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

        String hijriDay = today['hijri_day'].toString();
        String hijriMonth = today['hijri_month_name'];
        String hijriYear = today['hijri_year'].toString();

        String gregorianDay = today['gregorian_day'].toString();
        String gregorianMonth = today['gregorian_month'];
        String gregorianYear = today['gregorian_year'].toString();

        combinedDate = '$gregorianDay $gregorianMonth $gregorianYear\n'
            '$hijriDay $hijriMonth $hijriYear';
      });
    }
  }

  // -------------------------------------------
  // حساب الوقت المتبقي للصلاة التالية + تحديد مدة الفترة بين الصلاتين
  // -------------------------------------------
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
      DateTime? previousPrayerTime;

      for (int i = 0; i < prayerTimes.length; i++) {
        List<String> timeParts = prayerTimes[i].split(':');
        DateTime currentPrayerTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        if (currentPrayerTime.isAfter(now)) {
          setState(() {
            nextPrayerName = prayerNames[i];
            timeUntilNextPrayer = currentPrayerTime.difference(now);

            previousPrayerTime ??= currentPrayerTime;

            totalPrayerWindow = currentPrayerTime.difference(
              previousPrayerTime ?? currentPrayerTime,
            );
          });
          foundNextPrayer = true;
          break;
        } else {
          previousPrayerTime = currentPrayerTime;
        }
      }

      if (!foundNextPrayer) {
        // الصلاة التالية فجر الغد
        List<String> fajrTimeParts = prayerTimes[0].split(':');
        DateTime nextFajrTime = DateTime(
          now.year,
          now.month,
          now.day + 1,
          int.parse(fajrTimeParts[0]),
          int.parse(fajrTimeParts[1]),
        );
        setState(() {
          nextPrayerName = prayerNames[0];
          timeUntilNextPrayer = nextFajrTime.difference(now);

          if (prayerTimes.isNotEmpty) {
            List<String> lastPrayerParts =
                prayerTimes[prayerTimes.length - 1].split(':');
            DateTime lastPrayerTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(lastPrayerParts[0]),
              int.parse(lastPrayerParts[1]),
            );
            previousPrayerTime = lastPrayerTime;
          } else {
            previousPrayerTime = nextFajrTime;
          }

          totalPrayerWindow = nextFajrTime.difference(
            previousPrayerTime ?? nextFajrTime,
          );
        });
      }
    }
  }

  // -------------------------------------------
  // تحميل الآية اليومية
  // -------------------------------------------
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

  // -------------------------------------------
  // البناء الأساسي للواجهة
  // -------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white,
            width: 7,
          ),
          image: DecorationImage(
            image: AssetImage('assets/images/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // القسم العلوي
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // (اليسار) العد التنازلي + شريط التقدم
                    _buildLeftSection(),

                    // (الوسط) الساعة
                    Expanded(
                      child: Center(
                        child: _buildClockSection(),
                      ),
                    ),

                    // (اليمين) اليوم + التاريخ + المناسبة
                    _buildRightDateSection(),
                  ],
                ),
              ),

              Spacer(),

              // شريط أوقات الصلاة
              _buildTimeRowSection(),

              // آية اليوم
              _buildDailyVerseSection(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------
  // (يسار) العد التنازلي + الشريط
  // -------------------------------------------
  Widget _buildLeftSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 100.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (nextPrayerName != null) ...[
              Text(
                'الوقت المتبقي لصلاة $nextPrayerName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 50,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 150),
            ],
            if (timeUntilNextPrayer != null) ...[
              Text(
                _formatDuration(timeUntilNextPrayer!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 60,
                  color: Colors.white,
                  fontFamily: 'Digital',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            SizedBox(height: 200),
            Container(
              width: MediaQuery.of(context).size.width * 0.25,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: LinearProgressIndicator(
                  value: _calculateProgressValue(),
                  backgroundColor: Colors.grey[300],
                  color: const ui.Color.fromARGB(255, 5, 2, 18),
                  minHeight: 50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تنسيق المدة (hh:mm:ss)
  String _formatDuration(Duration d) {
    String hh = d.inHours.toString().padLeft(2, '0');
    String mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    String ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  // -------------------------------------------
  // (وسط) الساعة + العقارب
  // -------------------------------------------
  Widget _buildClockSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 200.0),
      child: SizedBox(
        width: 400,
        height: 400,
        child: Stack(
          children: [
            // خلفية صورة الساعة
            Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/Clock.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // رسم العقارب
            CustomPaint(
              size: Size(400, 400),
              painter: _ClockHandsPainter(_currentTime),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------
  // (اليمين) اليوم + التاريخ + المناسبة
  // -------------------------------------------
  Widget _buildRightDateSection() {
    String dayName = todayData?['day_of_week'] ?? '';
    String? eventName = todayData?['event'];

    return Padding(
      padding: const EdgeInsets.only(top: 100.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dayName.isNotEmpty) ...[
              Text(
                dayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 70,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 90),
            ],
            if (combinedDate != null) ...[
              Text(
                combinedDate!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 50,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 90),
            ],
            if (eventName != null) ...[
              Text(
                'مناسبة اليوم\n$eventName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 50,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------
  // شريط أوقات الصلاة السفلي
  // -------------------------------------------
  Widget _buildTimeRowSection() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/time-row.png'),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPrayerTimeItem('المغرب', todayData?['maghrib_hour'],
              todayData?['maghrib_minute']),
          _buildPrayerTimeItem(
              'الظهر', todayData?['dhuhr_hour'], todayData?['dhuhr_minute']),
          _buildPrayerTimeItem('الشروق', todayData?['sunrise_hour'],
              todayData?['sunrise_minute']),
          _buildPrayerTimeItem(
              'الصبح', todayData?['fajr_hour'], todayData?['fajr_minute']),
        ],
      ),
    );
  }

  Widget _buildPrayerTimeItem(String prayerName, dynamic hour, dynamic minute) {
    String displayTime = '';
    if (hour != null && minute != null) {
      int hourInt = int.parse(hour.toString());
      int minuteInt = int.parse(minute.toString());

      // تحويل إلى 12 ساعة
      int hour12 = hourInt > 12 ? hourInt - 12 : (hourInt == 0 ? 12 : hourInt);
      String period = hourInt >= 12 ? 'PM' : 'AM';
      displayTime =
          '${hour12.toString().padLeft(2, '0')}:${minuteInt.toString().padLeft(2, '0')} $period';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prayerName,
          style: TextStyle(
            fontSize: 50,
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
        SizedBox(height: 15),
        Text(
          displayTime,
          style: TextStyle(
            fontSize: 52,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------
  // الآية اليومية في الأسفل
  // -------------------------------------------
  Widget _buildDailyVerseSection() {
    if (dailyVerse == null) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(40),
      child: Text(
        dailyVerse!,
        style: TextStyle(
          fontSize: 35,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // -------------------------------------------
  // يحسب نسبة التقدم بين الصلاة السابقة والحالية
  // -------------------------------------------
  double _calculateProgressValue() {
    if (timeUntilNextPrayer == null || totalPrayerWindow == null) {
      return 0.0;
    }

    double remainingSec = timeUntilNextPrayer!.inSeconds.toDouble();
    double totalSec = totalPrayerWindow!.inSeconds.toDouble();

    double progress = 1 - (remainingSec / totalSec);

    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    return progress;
  }
}

// =====================================================================
// رسّام مخصّص لرسم العقارب فوق صورة الساعة
// =====================================================================
class _ClockHandsPainter extends CustomPainter {
  final DateTime now;
  _ClockHandsPainter(this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // حساب الزوايا
    // الزاوية بالدرجات = (القيمة / الحد الأقصى) * 360
    // الدقائق والثواني: من 0 إلى 59
    // الساعات: من 0 إلى 12
    final seconds = now.second + (now.millisecond / 1000.0);
    final minutes = now.minute + (seconds / 60.0);
    final hours = (now.hour % 12) + (minutes / 60.0);

    // الزوايا (بالراديان)
    final secondAngle = (seconds * 6) * (pi / 180);
    final minuteAngle = (minutes * 6) * (pi / 180);
    final hourAngle = (hours * 30) * (pi / 180);

    // طول العقارب
    final radius = size.width * 0.4; // أو حسب رغبتك
    final hourHandLength = radius * 0.5;
    final minuteHandLength = radius * 0.7;
    final secondHandLength = radius * 0.8;

    // فرش الرسم
    final hourPaint = Paint()
      ..color = const ui.Color.fromARGB(255, 0, 0, 0)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final minutePaint = Paint()
      ..color = const ui.Color.fromARGB(255, 0, 0, 0)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final secondPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // رسم عقرب الساعات
    final hourX = center.dx + hourHandLength * sin(hourAngle);
    final hourY = center.dy - hourHandLength * cos(hourAngle);
    canvas.drawLine(center, Offset(hourX, hourY), hourPaint);

    // رسم عقرب الدقائق
    final minX = center.dx + minuteHandLength * sin(minuteAngle);
    final minY = center.dy - minuteHandLength * cos(minuteAngle);
    canvas.drawLine(center, Offset(minX, minY), minutePaint);

    // رسم عقرب الثواني
    final secX = center.dx + secondHandLength * sin(secondAngle);
    final secY = center.dy - secondHandLength * cos(secondAngle);
    canvas.drawLine(center, Offset(secX, secY), secondPaint);
  }

  @override
  bool shouldRepaint(_ClockHandsPainter oldDelegate) {
    return oldDelegate.now != now;
  }
}
