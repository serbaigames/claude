import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iskra/main.dart';
import 'package:iskra/ui/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('приложение запускается, вступление закрывается, вкладки открываются', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs);
    await tester.pumpWidget(IskraApp(controller: ctl));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Искра во тьме'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Искра во тьме'), findsNothing);
    expect(find.text('Материя'), findsWidgets);

    // выбрать соседнюю клетку тьмы и открыть окно боя
    final dark = ctl.game.vis.map(ctl.game.cell).firstWhere((c) => c != null && !c.own)!;
    ctl.select(dark.key);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('В бой').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Начать бой'), findsOneWidget);
    await tester.tap(find.text('Отступить'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ctl.game.b, isNull);

    for (final t in ['Персонаж', 'Способности', 'Артефакты', 'Технологии', 'Эры', 'Аккаунт']) {
      final chip = find.widgetWithText(ChoiceChip, t);
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Статистика'), findsOneWidget);
    expect(prefs.getString(GameController.saveKey), isNull, reason: 'сохранение раз в 5 секунд');
    await tester.pump(const Duration(seconds: 6));
    expect(prefs.getString(GameController.saveKey), isNotNull);
  });
}
