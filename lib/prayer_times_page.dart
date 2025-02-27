import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
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

  List<String> imageUrls = [];
  int currentIndex = 0;
  Timer? _imageTimer;

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
    fetchImages();
    startImageLoop();
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
    _imageTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchImages() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://127.0.0.1:8000/api/user/images-by-mosque?mosqueName=${widget.mosqueName}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          imageUrls = List<String>.from(
              data['images'].map((image) => image['url'].toString()));
        });
      } else {
        print("⚠️ فشل تحميل الصور من API");
      }
    } catch (e) {
      print("خطأ أثناء جلب الصور: $e");
    }
  }

  void startImageLoop() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      setState(() {
        currentIndex = (currentIndex + 1) % imageUrls.length;
      });
    });
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
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          _buildClockSection(),
                          _buildImageBox(),
                          _buildDailyVerseBox(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildTimeRowSection(),
              _buildRightBoxesRow(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  المربع اليمين
  // -------------------------------------------------------------------------
  Widget _buildClockSection() {
    // حساب الوقت بصيغة 12 ساعة
    final hour = _currentTime.hour % 12 == 0 ? 12 : _currentTime.hour % 12;
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final second = _currentTime.second.toString().padLeft(2, '0');
    final period = _currentTime.hour >= 12 ? "PM" : "AM";

    // استخراج بيانات اليوم من todayData
    String dayName = todayData?['day_of_week'] ?? '';
    String gregorianDate = (todayData == null)
        ? ''
        : '${todayData!['gregorian_day']} ${todayData!['gregorian_month']} ${todayData!['gregorian_year']}';
    String hijriDate = (todayData == null)
        ? ''
        : '${todayData!['hijri_day']} ${todayData!['hijri_month_name']} ${todayData!['hijri_year']}';

    return Align(
      alignment: Alignment.topRight,
      child: Container(
        // تصغير حجم المربع
        width: MediaQuery.of(context).size.width * 0.2,
        height: 400,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2), // خلفية نصف شفافة
          borderRadius: BorderRadius.circular(16), // حواف مقوسة
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          // لجعل جميع العناصر في المنتصف
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1) اسم اليوم
            if (dayName.isNotEmpty)
              Text(
                dayName,
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 15),

            // 2) الساعة الزمنية
            _buildClockWithPeriod(hour, minute, second, period),
            const SizedBox(height: 15),

            // 3) التاريخ الميلادي
            if (gregorianDate.isNotEmpty)
              Text(
                gregorianDate,
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 10),

            // 4) التاريخ الهجري
            if (hijriDate.isNotEmpty)
              Text(
                hijriDate,
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockWithPeriod(
    int hour,
    String minute,
    String second,
    String period,
  ) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        children: [
          TextSpan(
            text: "$hour:$minute:$second ",
            style: const TextStyle(fontSize: 45),
          ),
          TextSpan(
            text: period,
            style: const TextStyle(fontSize: 25),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // المربع وسط الصوره
  // -------------------------------------------------------------------------
  Widget _buildImageBox() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrls.isNotEmpty
            ? Image.network(
                imageUrls[currentIndex],
                key: ValueKey(imageUrls[
                    currentIndex]), // يجبر Flutter على تحديث الصورة عند التغيير
                fit: BoxFit.cover,
                headers: {
                  "Access-Control-Allow-Origin": "*"
                }, // ✅ السماح بتحميل الصور
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  print(
                      "⚠️ فشل تحميل الصورة: ${imageUrls[currentIndex]}"); // ✅ طباعة الخطأ في Debug Console
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 50, color: Colors.red),
                      SizedBox(height: 10),
                      Text("فشل تحميل الصورة",
                          style: TextStyle(color: Colors.white)),
                    ],
                  );
                },
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // المربع  يسار
  // -------------------------------------------------------------------------
  Widget _buildDailyVerseBox() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.2,
        height: 400,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (dailyVerse == null)
              const Text(
                'جاري تحميل الآية...',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                dailyVerse!,
                style: const TextStyle(
                  fontSize: 25,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // شريط أوقات الصلا
  // -------------------------------------------------------------------------
  Widget _buildTimeRowSection() {
    return Container(
      height: 130,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCountdownBoxItem(), // عنصر العد التنازلي
          _buildPrayerBoxItem(
            'العشاء',
            "20",
            "00",
          ),

          _buildPrayerBoxItem(
            'المغرب',
            todayData?['maghrib_hour'],
            todayData?['maghrib_minute'],
          ),
          _buildPrayerBoxItem(
            'العصر',
            "20",
            "00",
          ),
          _buildPrayerBoxItem(
            'الظهر',
            todayData?['dhuhr_hour'],
            todayData?['dhuhr_minute'],
          ),
          _buildPrayerBoxItem(
            'الشروق',
            todayData?['sunrise_hour'],
            todayData?['sunrise_minute'],
          ),
          _buildPrayerBoxItem(
            'الفجر',
            todayData?['fajr_hour'],
            todayData?['fajr_minute'],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBoxItem() {
    String countdownText = timeUntilNextPrayer != null
        ? _formatDuration(timeUntilNextPrayer!)
        : "00:00:00";
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const ui.Color.fromARGB(255, 197, 191, 109),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'الوقت المتبقي لصلاة ${nextPrayerName ?? ''}',
            style: TextStyle(
              fontSize: 30,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            countdownText,
            style: TextStyle(
              fontSize: 32,
              color: Colors.black,
              fontFamily: 'Digital',
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerBoxItem(String prayerName, dynamic hour, dynamic minute) {
    String displayTime = '';
    if (hour != null && minute != null) {
      int hourInt = int.parse(hour.toString());
      int minuteInt = int.parse(minute.toString());
      int hour12 = hourInt > 12 ? hourInt - 12 : (hourInt == 0 ? 12 : hourInt);
      String period = hourInt >= 12 ? 'PM' : 'AM';
      displayTime =
          '${hour12.toString().padLeft(2, '0')}:${minuteInt.toString().padLeft(2, '0')} $period';
    }

    bool isNextPrayer =
        prayerName == nextPrayerName; // تحقق إذا كانت هذه الصلاة القادمة

    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isNextPrayer
            ? Colors.white
            : Colors.black, // الصلاة القادمة بيضاء والباقي أسود
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            prayerName,
            style: TextStyle(
              fontSize: 30,
              color: isNextPrayer
                  ? Colors.black
                  : Colors.white, // لون النص حسب الخلفية
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            displayTime,
            style: TextStyle(
              fontSize: 32,
              color: isNextPrayer
                  ? Colors.black
                  : Colors.white, // لون الوقت حسب الخلفية
              fontFamily: 'Almarai',
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String hh = d.inHours.toString().padLeft(2, '0');
    String mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    String ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  // -------------------------------------------------------------------------
  // شريط السفلي الحذيث + المناسبات
  // -------------------------------------------------------------------------
  Widget _buildRightDateSection() {
    String eventName = todayData?['event'] ?? 'لا يوجد';

    return Container(
      margin: const EdgeInsets.only(
        top: 40.0,
      ),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
      child: Text(
        'مناسبة اليوم : $eventName',
        style: const TextStyle(
          fontSize: 30,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHadithBox() {
    return Container(
      margin: const EdgeInsets.only(
        top: 40.0,
        right: 10.0,
      ),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 800,
        ),
        child: Text(
          dailyHadith ?? 'لا يوجد حديث اليوم',
          style: const TextStyle(
            fontSize: 30,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  Widget _buildRightBoxesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildRightDateSection(),
        const SizedBox(width: 10),
        _buildHadithBox(),
      ],
    );
  }
}
