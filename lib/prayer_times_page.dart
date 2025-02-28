import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:prayertime/prayer_notification_page.dart';
import 'package:marquee/marquee.dart';

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

  Future<List<dynamic>> getPrayerTimesByMosque(String mosqueName) async {
    final url = Uri.parse(
        'http://127.0.0.1:8000/api/prayer-times/by-mosque?mosqueName=$mosqueName');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        return body['data'];
      } else {
        throw Exception(body['message']);
      }
    } else {
      throw Exception('فشل تحميل ملف أوقات الصلاة');
    }
  }

  // -------------------------------------------------------------------------
  // تحميل بيانات اليوم من ملف prayer_times.json
  // -------------------------------------------------------------------------
  Future<void> loadPrayerTimes() async {
    try {
      // 1) جلب كامل بيانات الصلاة الخاصة بالمسجد من API
      final List<dynamic> sheetData =
          await getPrayerTimesByMosque(widget.mosqueName);

      // 2) الحصول على التاريخ الحالي من الجهاز
      final DateTime now = DateTime.now();
      final int currentDay = now.day;
      final String currentMonthEnglish = DateFormat('MMMM').format(now);
      final String currentDayOfWeekEnglish = DateFormat('EEEE').format(now);
      final int currentYear = now.year;

      // 3) تحويل الأسماء الإنجليزية للعربية
      final String currentMonth =
          englishToArabicMonths[currentMonthEnglish] ?? currentMonthEnglish;
      final String currentDayOfWeek =
          englishToArabicDays[currentDayOfWeekEnglish] ??
              currentDayOfWeekEnglish;

      // 4) البحث عن سجل اليوم
      final today = sheetData.firstWhere(
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
        });
      } else {
        print("لم يتم العثور على تاريخ اليوم في بيانات الـAPI.");
      }
    } catch (e) {
      print('Error loading prayer times from API: $e');
    }
  }

  // -------------------------------------------------------------------------
  // حساب الوقت المتبقي للصلاة التالية
  // -------------------------------------------------------------------------
  void calculateTimeUntilNextPrayer() {
    if (todayData == null) {
      setState(() {
        nextPrayerName = null;
        timeUntilNextPrayer = null;
      });
      return;
    }

    // استخدام المسميات الجديدة للأوقات من JSON مع التحقق من وجودها
    List<Map<String, String>> prayers = [
      if (todayData?['fajr'] != null)
        {'name': 'الفجر', 'time': todayData!['fajr']},
      if (todayData?['sunrise'] != null)
        {'name': 'الشروق', 'time': todayData!['sunrise']},
      if (todayData?['dhuhr'] != null)
        {'name': 'الظهر', 'time': todayData!['dhuhr']},
      if (todayData?['asr'] != null)
        {'name': 'العصر', 'time': todayData!['asr']},
      if (todayData?['maghrib'] != null)
        {'name': 'المغرب', 'time': todayData!['maghrib']},
      if (todayData?['isha'] != null)
        {'name': 'العشاء', 'time': todayData!['isha']},
    ];

    DateTime now = DateTime.now();
    bool foundNextPrayer = false;
    DateTime? previousPrayerTime;

    for (var prayer in prayers) {
      String? prayerTime = prayer['time'];
      if (prayerTime == null || !prayerTime.contains(':'))
        continue; // تجنب القيم غير الصالحة

      List<String> timeParts = prayerTime.split(':');
      int? hour = int.tryParse(timeParts[0]);
      int? minute = int.tryParse(timeParts[1]);

      if (hour == null || minute == null) continue; // تخطي القيم غير الصالحة

      DateTime currentPrayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (currentPrayerTime.isAfter(now)) {
        setState(() {
          nextPrayerName = prayer['name'];
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

    // إذا لم نجد صلاة تالـيـة اليوم -> الصلاة التالية هي الفجر في اليوم التالي (إذا كان موجودًا)
    if (!foundNextPrayer && prayers.isNotEmpty) {
      var fajrPrayer = prayers.firstWhere(
        (prayer) => prayer['name'] == 'الفجر',
        orElse: () => {},
      );

      if (fajrPrayer.isNotEmpty && fajrPrayer['time'] != null) {
        List<String> fajrTimeParts = fajrPrayer['time']!.split(':');
        int? fajrHour = int.tryParse(fajrTimeParts[0]);
        int? fajrMinute = int.tryParse(fajrTimeParts[1]);

        if (fajrHour != null && fajrMinute != null) {
          DateTime nextFajrTime = DateTime(
            now.year,
            now.month,
            now.day + 1,
            fajrHour,
            fajrMinute,
          );

          setState(() {
            nextPrayerName = fajrPrayer['name']; // الفجر
            timeUntilNextPrayer = nextFajrTime.difference(now);

            // آخر صلاة في اليوم الحالي نفترضها العشاء إن وجدت
            var lastPrayer = prayers.last;
            if (lastPrayer['time'] != null) {
              List<String> lastPrayerParts = lastPrayer['time']!.split(':');
              int? lastPrayerHour = int.tryParse(lastPrayerParts[0]);
              int? lastPrayerMinute = int.tryParse(lastPrayerParts[1]);

              if (lastPrayerHour != null && lastPrayerMinute != null) {
                DateTime lastPrayerTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  lastPrayerHour,
                  lastPrayerMinute,
                );

                totalPrayerWindow = nextFajrTime.difference(lastPrayerTime);
              }
            }
          });
        }
      }
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
      String jsonString = await rootBundle.loadString('assets/hadith.json');
      Map<String, dynamic> jsonData = json.decode(jsonString);
      List<dynamic> hadithList = jsonData["Sheet 4"];

      // جمع جميع الأحاديث في قائمة نصية
      List<String> hadiths =
          hadithList.map((hadith) => hadith.values.first.toString()).toList();

      // دمج الأحاديث مع فاصل بين كل حديث والآخر
      setState(() {
        dailyHadith = hadiths.join("       |       ");
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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildImageBox(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _buildClockSection(),
                    ),
                  ],
                ),
              ),
              _buildTimeRowSection(),
              Expanded(child: Container()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildHadithTicker(),
    );
  }

  // -------------------------------------------------------------------------
  // المربع اليمين مع عرض اسم المسجد فوق اسم اليوم وإضافة كافة العناصر بتنسيق متساوٍ
  // -------------------------------------------------------------------------
  Widget _buildClockSection() {
    final hour = _currentTime.hour % 12 == 0 ? 12 : _currentTime.hour % 12;
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final second = _currentTime.second.toString().padLeft(2, '0');
    final period = _currentTime.hour >= 12 ? "PM" : "AM";

    String dayName = todayData?['day_of_week'] ?? '';
    String gregorianDate = (todayData == null)
        ? ''
        : '${todayData!['gregorian_day']} ${todayData!['gregorian_month']} ${todayData!['gregorian_year']}';
    String hijriDate = (todayData == null)
        ? ''
        : '${todayData!['hijri_day']} ${todayData!['hijri_month_name']} ${todayData!['hijri_year']}';
    String event = todayData?['event'] ?? '';

    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        height: 500,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly, // توزيع متساوٍ للعناصر
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 0) اسم المسجد
            Text(
              widget.mosqueName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            // 1) اسم اليوم
            if (dayName.isNotEmpty)
              Text(
                dayName,
                style: const TextStyle(
                  fontSize: 70,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            // 2) الساعة الزمنية
            _buildClockWithPeriod(hour, minute, second, period),
            // 3) التاريخ الميلادي
            if (gregorianDate.isNotEmpty)
              Text(
                gregorianDate,
                style: const TextStyle(
                  fontSize: 35,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                textDirection: ui.TextDirection.rtl,
              ),
            // 4) التاريخ الهجري
            if (hijriDate.isNotEmpty)
              Text(
                hijriDate,
                style: const TextStyle(
                  fontSize: 35,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                textDirection: ui.TextDirection.rtl,
              ),
            // 5) مناسبات اليوم (تقلص الخط إذا كان السطر طويل)
            if (event.isNotEmpty)
              Text(
                'مناسبة اليوم: $event',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            style: const TextStyle(fontSize: 60),
          ),
          TextSpan(
            text: period,
            style: const TextStyle(fontSize: 40),
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
      height: 500,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrls.isNotEmpty
            ? Image.network(
                imageUrls[currentIndex],
                key: ValueKey(imageUrls[currentIndex]),
                fit: BoxFit.contain,
                headers: {
                  "Access-Control-Allow-Origin": "*"
                }, // ✅ السماح بتحميل الصور
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  print("⚠️ فشل تحميل الصورة: ${imageUrls[currentIndex]}");
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
  // Widget _buildDailyVerseBox() {
  //   return Align(
  //     alignment: Alignment.topLeft,
  //     child: Container(
  //       width: MediaQuery.of(context).size.width * 0.2,
  //       height: 400,
  //       padding: const EdgeInsets.all(16.0),
  //       decoration: BoxDecoration(
  //         color: Colors.white.withOpacity(0.2),
  //         borderRadius: BorderRadius.circular(16),
  //         border: Border.all(color: Colors.white, width: 2),
  //       ),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           if (dailyVerse == null)
  //             const Text(
  //               'جاري تحميل الآية...',
  //               style: TextStyle(
  //                 fontSize: 20,
  //                 color: Colors.white,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //               textAlign: TextAlign.center,
  //             )
  //           else
  //             Text(
  //               dailyVerse!,
  //               style: const TextStyle(
  //                 fontSize: 25,
  //                 color: Colors.white,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //               textAlign: TextAlign.center,
  //               softWrap: true,
  //               maxLines: 5,
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // -------------------------------------------------------------------------
  // شريط أوقات الصلا
  // -------------------------------------------------------------------------

  Widget _buildTimeRowSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // عنصر العد التنازلي بعرض ثابت
          SizedBox(
            width: 300, // العرض الثابت المطلوب للعد التنازلي
            child: _buildCountdownBoxItem(),
          ),
          // باقي عناصر الصلاة تُغلف بـ Expanded لتتوزع بالتساوي
          if ((todayData?['isha'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
                child: _buildPrayerBoxItem(
                    'العشاء', todayData?['isha']?.toString())),
          ],
          if ((todayData?['maghrib'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
                child: _buildPrayerBoxItem(
                    'المغرب', todayData?['maghrib']?.toString())),
          ],
          if ((todayData?['asr'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
                child: _buildPrayerBoxItem(
                    'العصر', todayData?['asr']?.toString())),
          ],
          if ((todayData?['dhuhr'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
                child: _buildPrayerBoxItem(
                    'الظهر', todayData?['dhuhr']?.toString())),
          ],
          if ((todayData?['sunrise'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
                child: _buildPrayerBoxItem(
                    'الشروق', todayData?['sunrise']?.toString())),
          ],
          if ((todayData?['fajr'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
                child: _buildPrayerBoxItem(
                    'الفجر', todayData?['fajr']?.toString())),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownBoxItem() {
    String countdownText = timeUntilNextPrayer != null
        ? _formatDuration(timeUntilNextPrayer!)
        : "00:00:00";

    return Container(
      // هنا لم نعد نحدد العرض الثابت لأننا نستخدم SizedBox في الصف الخارجي
      height: 120,
      padding: const EdgeInsets.all(8.0),
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
            ' المتبقي لصلاة ${nextPrayerName ?? ''}',
            style: const TextStyle(
              fontSize: 30,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            countdownText,
            style: const TextStyle(
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

  Widget _buildPrayerBoxItem(String prayerName, String? prayerTime) {
    if (prayerTime == null || prayerTime.isEmpty) return const SizedBox();
    bool isNextPrayer = (prayerName == nextPrayerName);
    return Container(
      height: 120,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isNextPrayer ? Colors.white : Colors.black,
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
              color: isNextPrayer ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            prayerTime,
            style: TextStyle(
              fontSize: 30,
              color: isNextPrayer ? Colors.black : Colors.white,
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
  // شريط الحديث المتحرك (مثل شريط الأخبار)
  // -------------------------------------------------------------------------
// -------------------------------------------------------------------------
// شريط الحديث المتحرك (مثل شريط الأخبار)
// -------------------------------------------------------------------------
  Widget _buildHadithTicker() {
    return Container(
      height: 30, // تقليل الارتفاع ليشبه شريط الأخبار
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Marquee(
        text: dailyHadith ?? 'لا يوجد حديث اليوم',
        style: const TextStyle(
          fontSize: 18,
          color: ui.Color.fromARGB(255, 0, 0, 0),
          fontWeight: FontWeight.bold,
        ),
        scrollAxis: Axis.horizontal,
        textDirection: ui.TextDirection.rtl,
        blankSpace: 50,
        velocity: 50.0,
        pauseAfterRound: const Duration(seconds: 1),
        startPadding: 10.0,
      ),
    );
  }
}
