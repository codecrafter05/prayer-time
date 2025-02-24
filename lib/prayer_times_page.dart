import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:prayertime/prayer_notification_page.dart';

class PrayerTimesPage extends StatefulWidget {
  final String mosqueName;
  const PrayerTimesPage({super.key, required this.mosqueName});

  @override
  _PrayerTimesPageState createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  Map<String, dynamic>? todayData;
  String? combinedDate;
  Duration? timeUntilNextPrayer;
  String? nextPrayerName;
  Duration? totalPrayerWindow;
  Timer? countdownTimer;
  DateTime _currentTime = DateTime.now();
  String? dailyVerse;
  Timer? _refreshTimer;
  String? dailyHadith;

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
    loadPrayerTimes().then((_) {
      calculateTimeUntilNextPrayer();
      startCountdown();
    });
    loadDailyVerse();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchAndUpdateData();
    });
    _loadDailyHadith();
  }

  Future<void> _fetchAndUpdateData() async {
    await loadPrayerTimes();
    setState(() {
      calculateTimeUntilNextPrayer();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // تحميل بيانات اليوم من ملف prayer_times.json
  // -------------------------------------------------------------------------
  Future<void> loadPrayerTimes() async {
    try {
      String jsonString =
          await rootBundle.loadString('assets/prayer_times.json');
      Map<String, dynamic> jsonData = json.decode(jsonString);

      // تاريخ اليوم لجهازك
      DateTime now = DateTime.now();
      int currentDay = now.day;
      String currentMonthEnglish = DateFormat('MMMM').format(now);
      String currentDayOfWeekEnglish = DateFormat('EEEE').format(now);
      int currentYear = now.year;

      // تحويل أسماء الشهر واليوم من إنجليزي إلى عربي
      String currentMonth =
          englishToArabicMonths[currentMonthEnglish] ?? currentMonthEnglish;
      String currentDayOfWeek = englishToArabicDays[currentDayOfWeekEnglish] ??
          currentDayOfWeekEnglish;

      // الوصول للبيانات من مفتاح "Sheet 2"
      List<dynamic> sheetData = jsonData["Sheet 2"];

      // إيجاد سجل اليوم
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

          // تجميع التاريخين لعرضهما في وسط الصفحة
          String hijriDay = today['hijri_day'].toString();
          String hijriMonth = today['hijri_month_name'];
          String hijriYear = today['hijri_year'].toString();

          String gregorianDay = today['gregorian_day'].toString();
          String gregorianMonth = today['gregorian_month'];
          String gregorianYear = today['gregorian_year'].toString();

          combinedDate = '$gregorianDay $gregorianMonth $gregorianYear\n'
              '$hijriDay $hijriMonth $hijriYear';
        });
      } else {
        print("لم يتم العثور على تاريخ اليوم في JSON. تأكد من تطابق التاريخ.");
      }
    } catch (e) {
      print('Error loading prayer_times.json: $e');
    }
  }

  // -------------------------------------------------------------------------
  // حساب الوقت المتبقي للصلاة التالية
  // (فجر + ظهر + عشاء فقط)
  // -------------------------------------------------------------------------
  void calculateTimeUntilNextPrayer() {
    if (todayData == null) {
      nextPrayerName = null;
      timeUntilNextPrayer = null;
      return;
    }

    // نضيف فقط الفجر، الظهر، العشاء (maghrib) من ملف JSON
    List<String> prayerTimes = [
      '${todayData!['fajr_hour']}:${todayData!['fajr_minute']}', // فجر
      '${todayData!['dhuhr_hour']}:${todayData!['dhuhr_minute']}', // ظهر
      '${todayData!['maghrib_hour']}:${todayData!['maghrib_minute']}' // عشاء
    ];

    List<String> prayerNames = [
      'الفجر',
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

    // إذا لم نجد صلاة تالـيـة اليوم -> الصلاة التالية هي الفجر في اليوم التالي
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
        nextPrayerName = prayerNames[0]; // الفجر
        timeUntilNextPrayer = nextFajrTime.difference(now);

        // آخر صلاة في اليوم الحالي نفترضها العشاء (prayerTimes[2])
        List<String> lastPrayerParts = prayerTimes[2].split(':');
        DateTime lastPrayerTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(lastPrayerParts[0]),
          int.parse(lastPrayerParts[1]),
        );

        totalPrayerWindow = nextFajrTime.difference(
          lastPrayerTime,
        );
      });
    }
  }

  // -------------------------------------------------------------------------
  // بدء مؤقت يحدث كل ثانية لتحديث:
  // 1) الوقت الحالي (للساعة الرقمية)
  // 2) الوقت المتبقي للصلاة (العد التنازلي)
  // عند بلوغ 0 -> إظهار إشعار 3 دقائق
  // -------------------------------------------------------------------------
  void startCountdown() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // تحديث الساعة الرقمية
      setState(() {
        _currentTime = DateTime.now();
      });

      // إن لم تُحسب بيانات اليوم أو الوقت المتبقي
      if (timeUntilNextPrayer == null) return;

      if (timeUntilNextPrayer!.inSeconds > 0) {
        // أنقص ثانية واحدة من العدّ التنازلي
        setState(() {
          timeUntilNextPrayer = timeUntilNextPrayer! - Duration(seconds: 1);
        });
      } else if (timeUntilNextPrayer!.inSeconds == 0) {
        // حان وقت الصلاة بالضبط
        timer.cancel();

        // إظهار صفحة الإشعار
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrayerNotificationPage(
                prayerName: nextPrayerName ?? "الصلاة",
              ),
            ),
          );

          // صفحة الإشعار تبقى 3 دقائق
          Future.delayed(const Duration(minutes: 3), () {
            if (mounted) {
              Navigator.pop(context);
            }

            // العودة للصفحة الرئيسية
            // نحسب الصلاة التالية ونستمر
            calculateTimeUntilNextPrayer();
            startCountdown();
          });
        });
      } else {
        // القيمة سالبة => فات وقت هذه الصلاة
        // تجاوزها واذهب للصلاة التالية
        timer.cancel();
        setState(() {
          calculateTimeUntilNextPrayer();
        });
        startCountdown();
      }
    });
  }

  // -------------------------------------------------------------------------
  // تحميل الآية اليومية
  // -------------------------------------------------------------------------
  Future<void> loadDailyVerse() async {
    try {
      String jsonString = await rootBundle.loadString('assets/quran.json');
      Map<String, dynamic> jsonData = json.decode(jsonString);

      List<dynamic> verses = jsonData["Sheet 3"];
      int dayOfYear = DateTime.now()
              .difference(DateTime(DateTime.now().year, 1, 1))
              .inDays +
          1;
      int verseIndex = dayOfYear % verses.length;
      String verse = verses[verseIndex].values.first;

      setState(() {
        dailyVerse = verse;
      });
    } catch (e) {
      print("Error loading quran.json: $e");
    }
  }

  // -------------------------------------------------------------------------
  // تحميل الاحاديث اليومية
  // -------------------------------------------------------------------------
  Future<void> _loadDailyHadith() async {
    try {
      // تحميل الملف
      String jsonString = await rootBundle.loadString('assets/hadith.json');

      // تحويل النص إلى JSON
      Map<String, dynamic> jsonData = json.decode(jsonString);

      // استخراج قائمة الأحاديث
      List<dynamic> hadithList = jsonData["Sheet 4"];

      // اختيار حديث عشوائي بناءً على اليوم
      setState(() {
        dailyHadith =
            hadithList[DateTime.now().day % hadithList.length].values.first;
      });
    } catch (e) {
      print("Error loading hadith.json: $e");
    }
  }

  // -------------------------------------------------------------------------
  // واجهة المستخدم
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // يمكنك أيضًا وضع اسم المسجد في العنوان:
      appBar: AppBar(
        title: Text('أوقات الصلاة لـ ${widget.mosqueName}'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 7),
          image: const DecorationImage(
            image: AssetImage('assets/images/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'مسجد: ${widget.mosqueName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeftSection(),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          _buildClockSection(),
                        ],
                      ),
                    ),
                    _buildRightDateSection(),
                  ],
                ),
              ),
              _buildDailyVerseSection(),
              _buildTimeRowSection(),
              _buildDailyHadithSection(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // (اليسار) العد التنازلي
  // -------------------------------------------------------------------------
  Widget _buildLeftSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 200.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (nextPrayerName != null) ...[
              Text(
                'المتبقي لصلاة $nextPrayerName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 15),
            ],
            if (timeUntilNextPrayer != null) ...[
              Text(
                _formatDuration(timeUntilNextPrayer!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontFamily: 'Digital',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// تحويل مدة زمنية إلى صيغة "HH:MM:SS"
  String _formatDuration(Duration d) {
    String hh = d.inHours.toString().padLeft(2, '0');
    String mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    String ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  // -------------------------------------------------------------------------
  // (الوسط) الساعة الرقمية + اليوم + التاريخ
  // -------------------------------------------------------------------------
  Widget _buildClockSection() {
    final hour = _currentTime.hour % 12 == 0 ? 12 : _currentTime.hour % 12;
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final second = _currentTime.second.toString().padLeft(2, '0');
    final period = _currentTime.hour >= 12 ? "مساءً" : "صباحاً";

    String dayName = todayData?['day_of_week'] ?? '';
    String hijriDate = (todayData == null)
        ? ''
        : '${todayData!['hijri_day']} ${todayData!['hijri_month_name']} ${todayData!['hijri_year']}';

    String gregorianDate = (todayData == null)
        ? ''
        : '${todayData!['gregorian_day']} ${todayData!['gregorian_month']} ${todayData!['gregorian_year']}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // اسم اليوم
        if (dayName.isNotEmpty)
          Text(
            dayName,
            style: TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        SizedBox(height: 50),

        // التاريخ الهجري والميلادي
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // أو حسب ما تريد
          textDirection: ui.TextDirection.rtl,
          children: [
            if (hijriDate.isNotEmpty)
              Text(
                hijriDate,
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                ),
                textDirection: ui.TextDirection.rtl,
              ),

            // عنصر فارغ يفصل بين التاريخين
            if (hijriDate.isNotEmpty && gregorianDate.isNotEmpty)
              SizedBox(width: 115), // يمكنك تغيير القيمة حسب المسافة المطلوبة

            if (gregorianDate.isNotEmpty)
              Text(
                gregorianDate,
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                ),
                textDirection: ui.TextDirection.rtl,
              ),
          ],
        ),

        SizedBox(height: 30),

        // الساعة الرقمية
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(
                text: "$hour:$minute ",
                style: TextStyle(fontSize: 80),
              ),
              TextSpan(
                text: second,
                style: TextStyle(fontSize: 60),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),

        // صباحًا أو مساءً
        Text(
          period,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // (اليمين) المناسبة
  // -------------------------------------------------------------------------
  Widget _buildRightDateSection() {
    String? eventName = todayData?['event'];
    return Padding(
      padding: const EdgeInsets.only(top: 200.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'مناسبة اليوم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              eventName ?? 'لا يوجد',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // شريط أوقات الصلاة (ثلاث صلوات فقط: فجر، ظهر، المغرب)
  // -------------------------------------------------------------------------
  Widget _buildTimeRowSection() {
    return Container(
      height: 130,
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
            'المغرب',
            todayData?['maghrib_hour'],
            todayData?['maghrib_minute'],
          ),
          _buildPrayerTimeItem(
            'الظهر',
            todayData?['dhuhr_hour'],
            todayData?['dhuhr_minute'],
          ),
          _buildPrayerTimeItem(
            'الشروق',
            todayData?['sunrise_hour'],
            todayData?['sunrise_minute'],
          ),
          _buildPrayerTimeItem(
            'الفجر',
            todayData?['fajr_hour'],
            todayData?['fajr_minute'],
          ),
        ],
      ),
    );
  }

  /// عنصر واحد في شريط أوقات الصلاة
  Widget _buildPrayerTimeItem(String prayerName, dynamic hour, dynamic minute) {
    String displayTime = '';
    if (hour != null && minute != null) {
      int hourInt = int.parse(hour.toString());
      int minuteInt = int.parse(minute.toString());

      // تحويل 24-ساعة إلى 12-ساعة
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
            fontSize: 30,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 15),
        Text(
          displayTime,
          style: TextStyle(
            fontSize: 32,
            color: Colors.white,
            fontFamily: 'Almarai',
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // آية اليوم في الأسفل
  // -------------------------------------------------------------------------
  Widget _buildDailyVerseSection() {
    if (dailyVerse == null) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(25),
      child: Text(
        dailyVerse!,
        style: TextStyle(
          fontSize: 30,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // الحديث اليومي في الوسط
  // -------------------------------------------------------------------------
  Widget _buildDailyHadithSection() {
    if (dailyHadith == null) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(25),
      child: Text(
        dailyHadith!,
        style: TextStyle(
          fontSize: 25,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
