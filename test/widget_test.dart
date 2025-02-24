import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayertime/welcome_page.dart';

void main() {
  testWidgets('عرض صفحة الترحيب وعناصرها الأساسية',
      (WidgetTester tester) async {
    // ✅ بناء التطبيق وعرض الشاشة
    await tester.pumpWidget(MaterialApp(home: WelcomePage()));

    // ✅ التحقق من وجود عنوان الترحيب
    expect(find.text('مرحبًا بك في تطبيق أوقات الصلاة'), findsOneWidget);

    // ✅ التحقق من وجود القائمة المنسدلة لاختيار المسجد
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    // ✅ التحقق من وجود زر "إنشاء تطبيقي"
    expect(find.widgetWithText(ElevatedButton, 'إنشاء تطبيقي'), findsOneWidget);
  });
}
