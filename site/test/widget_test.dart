import 'package:asb_studio/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('главная показывает идею и проект «Искра»', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AsbStudioApp());
    expect(
      find.text('Миры, которые растут и связаны между собой'),
      findsOneWidget,
    );
    expect(find.text('Играть на iskraplay.ru'), findsOneWidget);

    await tester.tap(find.text('Поддержать').first);
    await tester.pumpAndSettle();
    expect(find.text('Как помочь'), findsOneWidget);
  });
}
