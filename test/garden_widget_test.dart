import 'dart:convert';
import 'package:dream_garden/main.dart';
import 'package:flame/game.dart';
import 'package:dream_garden/persian_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main(){
  Future<void> open(WidgetTester tester,Size size)async{
    tester.view.physicalSize=size;tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'dream_garden':jsonEncode({'introSeen':true})});
    await tester.pumpWidget(const DreamGarden());await tester.pump();await tester.pump(const Duration(milliseconds:600));
  }
  testWidgets('phone shows real Flame board and garden without overflow',(tester)async{
    await open(tester,const Size(390,844));
    expect(find.text('مرحله ۱'),findsOneWidget);expect(find.byType(GameWidget<PersianBoard>),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.tap(find.text('باغ ایرانی'));await tester.pump(const Duration(milliseconds:400));
    expect(find.text('دفترچه باغ'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());await tester.pump();
  });
  testWidgets('desktop shows board and Iranian restoration together',(tester)async{
    await open(tester,const Size(1280,960));expect(find.text('مرحله ۱'),findsOneWidget);expect(find.text('دفترچه باغ'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());await tester.pump();
  });
}
