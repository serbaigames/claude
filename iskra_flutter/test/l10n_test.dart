import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iskra/l10n/l10n.dart';
import 'package:iskra/main.dart';
import 'package:iskra/ui/controller.dart';
import 'package:iskra/ui/sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Видимые тексты на экране, в которых остались русские буквы
List<String> russianOnScreen(WidgetTester tester) {
  final ru = RegExp('[А-Яа-яЁё]');
  final out = <String>{};
  for (final w in tester.allWidgets) {
    final s = switch (w) {
      Text(:final data, :final textSpan) => data ?? textSpan?.toPlainText() ?? '',
      RichText(:final text) => text.toPlainText(),
      Tooltip(:final message) => message ?? '',
      _ => '',
    };
    if (ru.hasMatch(s) && s != Lang.ru.title) out.add(s); // название языка в переключателе не переводится
  }
  return out.toList();
}

void main() {
  tearDown(() => lang = Lang.ru);

  testWidgets('английский: в окнах и вкладках не остаётся русского текста', (tester) async {
    Sound.enabled = false;
    SharedPreferences.setMockInitialValues({'iskra-lang': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs);
    await tester.pumpWidget(IskraApp(controller: ctl));
    await tester.pump(const Duration(milliseconds: 100));
    expect(isEn, isTrue);
    final found = <String, List<String>>{};
    void check(String where) {
      final r = russianOnScreen(tester);
      if (r.isNotEmpty) found[where] = r;
    }

    check('intro');
    await tester.tap(find.text(tx('Начать')));
    await tester.pump(const Duration(milliseconds: 100));
    check('main');

    final dark = ctl.game.vis.map(ctl.game.cell).firstWhere((c) => c != null && !c.own)!;
    ctl.select(dark.key);
    await tester.pump(const Duration(milliseconds: 100));
    check('cell');
    await tester.tap(find.text(tx('Атаковать')));
    await tester.pump(const Duration(milliseconds: 100));
    check('battle');
    await tester.ensureVisible(find.text(tx('Отступить')));
    await tester.pump();
    await tester.tap(find.text(tx('Отступить')));
    await tester.pump(const Duration(milliseconds: 100));

    for (final t in ['Параметры\nискры', 'Способности', 'Артефакты', 'Технологии', 'Настройки']) {
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('menu-bar')), matching: find.text(tx(t))));
      await tester.pump(const Duration(milliseconds: 100));
      check(t);
    }
    for (final t in ['acc', 'app', 'shop', 'stats', 'about', 'dev']) {
      await tester.ensureVisible(find.byKey(ValueKey('set-$t')));
      await tester.tap(find.byKey(ValueKey('set-$t')));
      await tester.pump(const Duration(milliseconds: 100));
      check('settings/$t');
    }
    await tester.tap(find.byTooltip(tx('Закрыть')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip(tx('Эры')));
    await tester.pump(const Duration(milliseconds: 100));
    check('eras');

    expect(found, isEmpty, reason: 'русский текст в английской версии');

    // переключение обратно на русский перерисовывает интерфейс без перезапуска, окно остаётся открытым
    expect(
      find.text(
        'Матер'
        'ия',
      ),
      findsNothing,
    );
    ctl.setLang(Lang.ru);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Материя'), findsWidgets);
    expect(find.byKey(const ValueKey('window-era')), findsOneWidget);
    expect(prefs.getString(GameController.langKey), 'ru');
  });
}
