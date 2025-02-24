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
  List<String> mosques = [];
  String? selectedMosque;

  @override
  void initState() {
    super.initState();
    fetchMosques();
  }

  Future<void> fetchMosques() async {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:8000/api/mosques'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> mosquesList = data['mosques'];

        setState(() {
          mosques = mosquesList.map((mosque) => mosque.toString()).toList();
        });
      } else {
        throw Exception('فشل تحميل بيانات المساجد');
      }
    } catch (e) {
      print('خطأ أثناء جلب البيانات: $e');
    }
  }

  Future<void> _setDidSeeWelcomeAndMosque(String chosenMosque) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('didSeeWelcome', true);
    await prefs.setString('chosenMosque', chosenMosque);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // خلفية الصورة
        decoration: BoxDecoration(
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
                    Text(
                      'مرحبًا بك في تطبيق أوقات الصلاة',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // لون أبيض للوضوح
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),

                    SizedBox(
                      width: 550,
                      child: DropdownButtonFormField<String>(
                        value: selectedMosque,
                        isDense: true,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'اختر المسجد الخاص بك',
                          labelStyle: const TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.deepPurple, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.deepPurple, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.deepPurple, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                        elevation: 4, // إضافة تأثير الظل
                        dropdownColor: Colors.white,
                        borderRadius:
                            BorderRadius.circular(10), // زوايا مستديرة للقائمة
                        menuMaxHeight: 300, // ارتفاع أقصى للقائمة
                        itemHeight: 60, // ارتفاع كل عنصر
                        items: mosques.map((mosque) {
                          return DropdownMenuItem<String>(
                            value: mosque,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                mosque,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedMosque = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 30),

                    // زر "إنشاء تطبيقي"
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
                      onPressed: () async {
                        if (selectedMosque != null) {
                          await _setDidSeeWelcomeAndMosque(selectedMosque!);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MosqueAppPage(mosqueName: selectedMosque!),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الرجاء اختيار المسجد أولًا'),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'إنشاء تطبيقي',
                        style: TextStyle(fontSize: 18, color: Colors.white),
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

class MosqueAppPage extends StatelessWidget {
  final String mosqueName;

  MosqueAppPage({required this.mosqueName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 243, 243),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'تم إنشاء تطبيق خاص بـ $mosqueName',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PrayerTimesPage(mosqueName: mosqueName),
                      ),
                    );
                  },
                  child: Text(
                    'عرض أوقات الصلاة',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
