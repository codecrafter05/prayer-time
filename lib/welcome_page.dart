import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_times_page.dart';

class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController mosqueCodeController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    checkIfAlreadyLoggedIn();
  }

  // ✅ التحقق إذا شاف الصفحة من قبل
  Future<void> checkIfAlreadyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    bool didSeeWelcome = prefs.getBool('didSeeWelcome') ?? false;
    String? chosenMosque = prefs.getString('chosenMosque');

    if (didSeeWelcome && chosenMosque != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PrayerTimesPage(mosqueName: chosenMosque),
        ),
      );
    }
  }

  // ✅ تحقق من الكود في السيرفر
  Future<void> verifyMosqueCode(String mosqueCode) async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/mosques/$mosqueCode'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String mosqueName = data['mosque_name']; // اسم المسجد اللي جاي من API

        await _setDidSeeWelcomeAndMosque(mosqueName);

        // ✅ توجه مباشرة إلى PrayerTimesPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PrayerTimesPage(mosqueName: mosqueName),
          ),
        );
      } else {
        _showError('❌ الكود غير صحيح');
      }
    } catch (e) {
      _showError('❌ خطأ أثناء الاتصال بالسيرفر');
    }

    setState(() => isLoading = false);
  }

  // ✅ حفظ بيانات الدخول
  Future<void> _setDidSeeWelcomeAndMosque(String chosenMosque) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('didSeeWelcome', true);
    await prefs.setString('chosenMosque', chosenMosque);
  }

  // ✅ عرض رسالة خطأ
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ✅ الخلفية
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'مرحبًا بك في تطبيق أوقات الصلاة',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // ✅ TextField للكود
                    SizedBox(
                      width: 550,
                      child: TextField(
                        controller: mosqueCodeController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'أدخل كود المسجد',
                          labelStyle: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ✅ زر دخول
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () {
                              String code = mosqueCodeController.text.trim();

                              if (code.isEmpty) {
                                _showError('⚠️ الرجاء إدخال كود المسجد');
                              } else {
                                verifyMosqueCode(code);
                              }
                            },
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'دخول',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
