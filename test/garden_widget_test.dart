import 'dart:convert';

import 'package:dream_garden/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> openAtPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DreamGarden());
    await tester.pumpAndSettle();
  }

  testWidgets('phone layout loads a playable board and opens garden', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await openAtPhoneSize(tester);
    expect(find.text('مرحله ۱'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('❧ باغ من'));
    await tester.pumpAndSettle();
    expect(find.text('۰ از ۵ بازسازی'), findsOneWidget);
    expect(find.text('اولین سلام به باغ'), findsOneWidget);
    await tester.ensureVisible(find.text('انتخاب دکور و بازسازی · ۱ ★'));
    await tester.tap(find.text('انتخاب دکور و بازسازی · ۱ ★'));
    await tester.pumpAndSettle();
    expect(find.text('با تمام‌کردن جورچین، ستاره بگیر.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restored rewards fund one decoration and persist the choice', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dream_garden': jsonEncode({
        'level': 3,
        'stars': 2,
        'coins': 150,
        'styles': [1],
        'hammers': 3,
        'shuffles': 2,
      }),
    });
    await openAtPhoneSize(tester);
    expect(find.text('مرحله ۳'), findsOneWidget);
    await tester.tap(find.text('❧ باغ من'));
    await tester.pumpAndSettle();
    expect(find.text('۱ از ۵ بازسازی'), findsOneWidget);
    await tester.ensureVisible(find.text('انتخاب دکور و بازسازی · ۱ ★'));
    await tester.tap(find.text('انتخاب دکور و بازسازی · ۱ ★'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🪑'));
    await tester.pumpAndSettle();
    expect(find.text('۲ از ۵ بازسازی'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final saved = jsonDecode(preferences.getString('dream_garden')!) as Map<String, dynamic>;
    expect(saved['styles'], [1, 0]);
    expect(saved['stars'], 1);
    expect(tester.takeException(), isNull);
  });
}
