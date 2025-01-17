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

  // تحميل بيانات أوقات الصلاة
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

        // لتجميع التاريخ في نص واحد (هجري + ميلادي)، مثلاً:
        combinedDate = '$gregorianDay $gregorianMonth $gregorianYear\n'
            '$hijriDay $hijriMonth $hijriYear';
      });
    }
  }

  // تحميل الآية اليومية
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

  // حساب الوقت المتبقي للصلاة التالية
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
        // إذا انتهت كل الصلوات اليوم، فالوقت التالي هو فجر اليوم التالي
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

  // تشغيل مؤقّت العدّ التنازلي
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

  // واجهة البناء الأساسية
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // خلفية الصفحة
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // -----------------------------------------
              // 1) القسم العلوي
              // -----------------------------------------
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ------ (اليسار) يوم الأسبوع + العد التنازلي + شريط التقدّم ------
                    _buildLeftSection(),

                    // ------ (الوسط) الساعة في المنتصف ------
                    Expanded(
                      child: Center(
                        child: _buildClockSection(),
                      ),
                    ),

                    // ------ (اليمين) التاريخ والمناسبة ------
                    _buildRightDateSection(),
                  ],
                ),
              ),

              // لإبقاء شريط أوقات الصلاة في الأسفل:
              Spacer(),

              // -----------------------------------------
              // 2) شريط أوقات الصلاة
              // -----------------------------------------
              _buildTimeRowSection(),

              // -----------------------------------------
              // 3) آية اليوم في الأسفل
              // -----------------------------------------
              _buildDailyVerseSection(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------
  // (يسار) اليوم + العد التنازلي + شريط التقدّم
  // -------------------------------------------
  Widget _buildLeftSection() {
    // استخرج اسم اليوم
    String dayName = todayData?['day_of_week'] ?? 'اليوم';

    return Container(
      width: MediaQuery.of(context).size.width * 0.3,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اليوم
          Text(
            dayName,
            style: TextStyle(
              fontSize: 50, // تكبير ليتناسب مع الشاشات الكبيرة
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),

          // النص: "الوقت المتبقي لصلاة كذا"
          if (nextPrayerName != null)
            Text(
              'الوقت المتبقي لصلاة $nextPrayerName',
              style: TextStyle(
                fontSize: 36, // تكبير إضافي
                color: Colors.black87,
              ),
            ),
          SizedBox(height: 20),

          // العد التنازلي
          if (timeUntilNextPrayer != null)
            Text(
              _formatDuration(timeUntilNextPrayer!),
              style: TextStyle(
                fontSize: 60, // عدّاد كبير
                color: Colors.redAccent,
                fontFamily: 'Digital',
              ),
            ),
          SizedBox(height: 30),

          // شريط التقدّم
          Container(
            width: MediaQuery.of(context).size.width * 0.25,
            child: LinearProgressIndicator(
              value: _calculateProgressValue(),
              backgroundColor: Colors.grey[300],
              color: Colors.redAccent,
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  // تنسيق المدة (hh:mm:ss) في العدّ التنازلي
  String _formatDuration(Duration d) {
    String hh = d.inHours.toString().padLeft(2, '0');
    String mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    String ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  // -------------------------------------------
  // (الوسط) الساعة
  // -------------------------------------------
  Widget _buildClockSection() {
    return Container(
      width: 400, // حجم أكبر للشاشات الكبيرة
      height: 400,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/Clock.png'),
          fit: BoxFit.contain,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '', // أو ضع "Clock" أو أي Placeholder
        style: TextStyle(color: Colors.white, fontSize: 28),
      ),
    );
  }

  // -------------------------------------------
  // (اليمين) اليوم + التاريخ + المناسبة
  // -------------------------------------------
  Widget _buildRightDateSection() {
    // إذا لم يتوفر اليوم في البيانات، استخدم نص افتراضي
    String dayName = todayData?['day_of_week'] ?? '';
    String? eventName = todayData?['event'];

    return Container(
      width: MediaQuery.of(context).size.width * 0.3,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // عرض اسم اليوم إذا كان غير فارغ
          if (dayName.isNotEmpty) ...[
            Text(
              dayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 50, // تكبير الخط لتناسب الشاشات الكبيرة
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
          ],

          // عرض التاريخ (هجري وميلادي) إن وجد
          if (combinedDate != null) ...[
            Text(
              combinedDate!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 45,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 40),
          ],

          // عرض المناسبة إن وجدت
          if (eventName != null) ...[
            Text(
              'مناسبة اليوم\n$eventName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------
  // شريط أوقات الصلاة السفلي
  // -------------------------------------------
  Widget _buildTimeRowSection() {
    return Container(
      height: 180, // أكبر من السابق
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
          _buildPrayerTimeItem(
              'الفجر', todayData?['fajr_hour'], todayData?['fajr_minute']),
          _buildPrayerTimeItem('الشروق', todayData?['sunrise_hour'],
              todayData?['sunrise_minute']),
          _buildPrayerTimeItem(
              'الظهر', todayData?['dhuhr_hour'], todayData?['dhuhr_minute']),
          _buildPrayerTimeItem('المغرب', todayData?['maghrib_hour'],
              todayData?['maghrib_minute']),
        ],
      ),
    );
  }

  // عنصر لعرض وقت الصلاة
  Widget _buildPrayerTimeItem(String prayerName, dynamic hour, dynamic minute) {
    String displayTime = '';
    if (hour != null && minute != null) {
      displayTime =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prayerName,
          style: TextStyle(
            fontSize: 40, // تكبير
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
        SizedBox(height: 15),
        Text(
          displayTime,
          style: TextStyle(
            fontSize: 42, // أكبر قليلًا للتوقيت
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
          fontSize: 35, // تكبير الخط للآية
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // -------------------------------------------
  // دالة بسيطة لحساب نسبة التقدم (مثال)
  // -------------------------------------------
  double _calculateProgressValue() {
    if (timeUntilNextPrayer == null) return 0.0;
    const int totalWindowSeconds = 7200;
    int remaining = timeUntilNextPrayer!.inSeconds;
    double progress = 1 - (remaining / totalWindowSeconds);
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    return progress;
  }
}
