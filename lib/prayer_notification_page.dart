import 'package:flutter/material.dart';

class PrayerNotificationPage extends StatelessWidget {
  final String prayerName;

  PrayerNotificationPage({required this.prayerName});

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(minutes: 3), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        // نضع العنصر في الوسط
        child: Center(
          // هنا سنضع مستطيل بخلفية time-row.png + إطار أبيض
          child: Container(
            height: 180,
            width: MediaQuery.of(context).size.width * 1, // عرض نسبي
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/time-row.png'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: Colors.white, width: 3),
            ),
            // نعرض النص في المنتصف
            child: Center(
              child: Text(
                'حان موعد صلاة $prayerName',
                style: TextStyle(
                  fontSize: 60,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
