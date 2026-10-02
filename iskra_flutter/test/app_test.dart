import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iskra/main.dart';
import 'package:iskra/ui/controller.dart';
import 'package:iskra/ui/gfx.dart';
import 'package:iskra/ui/sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('приложение запускается, вступление закрывается, вкладки открываются', (tester) async {
    Sound.enabled = false;
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
    expect(find.byKey(const ValueKey('cell-block')), findsOneWidget);
    await tester.tap(find.text('Атаковать'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Начать бой'), findsOneWidget);
    await tester.ensureVisible(find.text('Отступить'));
    await tester.pump();
    await tester.tap(find.text('Отступить'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ctl.game.b, isNull);

    for (final (t, key) in [
      ('Параметры\nискры', 'char'),
      ('Способности', 'abil'),
      ('Артефакты', 'art'),
      ('Технологии', 'tech'),
      ('Настройки', 'acc'),
    ]) {
      final item = find.descendant(of: find.byKey(const ValueKey('menu-bar')), matching: find.text(t));
      await tester.tap(item);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(ValueKey('window-$key')), findsOneWidget, reason: 'пункт «$t» открывается окном');
    }
    // настройки открываются на вкладке «Аккаунт»
    expect(find.byKey(const ValueKey('settings-tabs')), findsOneWidget);
    // «Начать заново» спрашивает подтверждение и перечисляет, что сбросится
    await tester.ensureVisible(find.text('Начать заново'));
    await tester.pump();
    await tester.tap(find.text('Начать заново'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('reset-dialog')), findsOneWidget);
    expect(find.text('артефакты'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('reset-dialog')), findsNothing);
    // качество графики переключается и сохраняется
    await tester.tap(find.byKey(const ValueKey('set-app')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Музыка'), findsOneWidget);
    expect(ctl.gfx, GfxLevel.high);
    await tester.ensureVisible(find.text('Лёгкий режим'));
    await tester.tap(find.text('Лёгкий режим'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ctl.gfx, GfxLevel.low);
    expect(prefs.getString(GameController.gfxKey), 'low');
    ctl.setGfx(GfxLevel.high);
    await tester.pump(const Duration(milliseconds: 100));
    // масштаб интерфейса: ×1 или авто
    expect(ctl.uiAuto.value, isTrue);
    final one = find.descendant(of: find.byKey(const ValueKey('ui-scale')), matching: find.text('×1'));
    await tester.ensureVisible(one);
    await tester.tap(one);
    await tester.pump(const Duration(milliseconds: 100));
    expect(ctl.uiAuto.value, isFalse);
    expect(prefs.getString(GameController.uiKey), '1');
    ctl.setUiAuto(true);
    await tester.pump(const Duration(milliseconds: 100));
    // громкость музыки сохраняется
    ctl.sound.setMusic(0.25);
    expect(prefs.getDouble('iskra-vol-music'), 0.25);
    for (final (t, key) in [('stats', 'stats'), ('about', 'app-version'), ('dev', 'donate-empty')]) {
      await tester.ensureVisible(find.byKey(ValueKey('set-$t')));
      await tester.tap(find.byKey(ValueKey('set-$t')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: 'вкладка $t');
    }
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('settings-tabs')), findsNothing);

    // кнопка эры слева вверху открывает окно эр, кнопка прыжка без технологии — окно технологий
    await tester.tap(find.byTooltip('Эры'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('window-era')), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Прыжок: нужна технология'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('window-tech')), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(prefs.getString(GameController.saveKey), isNull, reason: 'сохранение раз в 5 секунд');
    await tester.pump(const Duration(seconds: 6));
    expect(prefs.getString(GameController.saveKey), isNotNull);
  });
}
