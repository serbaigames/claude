import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iskra/l10n/l10n.dart';
import 'package:iskra/main.dart';
import 'package:iskra/ui/controller.dart';
import 'package:iskra/ui/panels.dart';
import 'package:iskra/ui/sound.dart';
import 'package:iskra/ui/tutorial.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> _ctl([Map<String, Object> prefs = const {}]) async {
  Sound.enabled = false;
  SharedPreferences.setMockInitialValues({'iskra-lang': 'ru', ...prefs});
  return GameController(await SharedPreferences.getInstance());
}

void main() {
  test('обучение идёт по шагам: дела засчитываются, пояснения — кнопкой', () async {
    final ctl = await _ctl();
    final g = ctl.game, t = ctl.tutor;
    expect(t.known, isTrue);
    expect(t.stage, 0);
    expect(t.view(g, null), isNull, reason: 'до закрытия вступления подсказок нет');
    ctl.act((g) => g.s.introSeen = true);

    // первый шаг указывает на сущность по соседству
    final v = t.view(g, null)!;
    expect(v.cell, isNotNull);
    expect(g.cell(v.cell)!.alive, isTrue);
    ctl.select(v.cell);
    expect(t.view(g, null)!.target, 'attack');

    void bump(String k) => ctl.act((g) => g.s.st[k] = (g.s.st[k] ?? 0) + 1);
    // сущность побеждена, а на захват не хватило материи: клетка свободна
    ctl.act((g) => g.cell(v.cell)!.alive = false);
    bump('wins');
    expect(t.view(g, null)!.target, 'capture');
    ctl.select(null);
    expect(t.view(g, null)!.cell, v.cell, reason: 'подсвечена свободная клетка');
    expect(TutStage.values[t.stage], TutStage.capture);
    bump('captured');
    expect(TutStage.values[t.stage], TutStage.build);
    bump('built');
    expect(TutStage.values[t.stage], TutStage.fortify);
    expect(t.view(g, null)!.button, isNotNull);
    ctl.tutorNext();
    expect(TutStage.values[t.stage], TutStage.char);
    expect(t.view(g, null)!.target, 'menu-char');
    expect(t.view(g, MenuTab.char)!.target, 'op-buy');
    ctl.act((g) => g.s.char['power'] = 2);
    expect(TutStage.values[t.stage], TutStage.tech);
    ctl.act((g) => g.researchTech('jump'));
    expect(g.hasTech('jump'), isTrue);
    expect(TutStage.values[t.stage], TutStage.time);
    ctl.tutorNext();
    expect(TutStage.values[t.stage], TutStage.jump);
    ctl.tutorNext();
    expect(t.done, isTrue);
    expect(t.view(g, null), isNull);

    // повтор из настроек снова просит каждое дело, а не засчитывает старые победы
    ctl.tutorRestart();
    expect(t.stage, 0);
    expect(TutStage.values[t.stage], TutStage.win);
    expect(jsonDecode(ctl.prefs.getString(Tutor.prefsKey)!)['stage'], 0);
  });

  test('у игрока со старым сохранением обучение не начинается', () async {
    final fresh = await _ctl();
    fresh.act((g) => g.s.introSeen = true);
    fresh.save();
    final save = fresh.prefs.getString(GameController.saveKey)!;
    final ctl = await _ctl({GameController.saveKey: save});
    expect(ctl.tutor.done, isTrue);
  });

  testWidgets('карточка обучения видна, пропускается и возвращается из настроек', (tester) async {
    final ctl = await _ctl();
    await tester.pumpWidget(IskraApp(controller: ctl));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tutor-card')), findsNothing);
    await tester.tap(find.text('Начать'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tutor-card')), findsOneWidget);
    expect(find.textContaining('шаг 1 из'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tutor-skip')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tutor-card')), findsNothing);
    expect(ctl.tutor.done, isTrue);

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('menu-bar')), matching: find.text('Настройки')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('set-app')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.byKey(const ValueKey('tutor-restart')));
    await tester.tap(find.byKey(const ValueKey('tutor-restart')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ctl.tutor.stage, 0);
    expect(find.byKey(const ValueKey('tutor-card')), findsOneWidget);
    lang = Lang.ru;
  });

  for (final (name, size) in [('планшет', Size(800, 600)), ('телефон', Size(390, 800))]) {
    testWidgets('обучение проходится через интерфейс ($name): каждая подсвеченная кнопка есть на экране', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (size.width < 500) {
        // тестовый шрифт Ahem шире настоящего: на узком экране переполнения строк здесь не показательны,
        // их ловит прогон на широком экране
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => d.exceptionAsString().contains('overflowed') ? null : prev?.call(d);
        addTearDown(() => FlutterError.onError = prev);
      }
      final ctl = await _ctl();
      await tester.pumpWidget(IskraApp(controller: ctl));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Начать'));
      await tester.pump(const Duration(milliseconds: 100));
      final g = ctl.game, t = ctl.tutor;

      /// Текущая подсказка указывает на элемент, который сейчас на экране; нажимаем его
      Future<void> tapTarget(String id) async {
        // подсказка прокручивает окно к кнопке
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final card = find.byKey(const ValueKey('tutor-card'));
        expect(card, findsOneWidget, reason: 'карточка на шаге $id');
        expect(t.rectOf(id), isNotNull, reason: 'подсвечен «$id»');
        final r = t.rectOf(id)!;
        await tester.tapAt(r.center);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(ctl.tutorCell, isNotNull);
      ctl.select(ctl.tutorCell);
      await tapTarget('attack');
      expect(g.b, isNotNull);
      await tapTarget('battle-start');
      expect(g.b!.started, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(t.rectOf('battle-abil'), isNotNull);
      g.s.matter = 1e6; // хватит и на бой, и на захват
      g.b!.foe.hp = 0;
      await tester.pump(const Duration(milliseconds: 400));
      expect(g.b!.over && g.b!.won, isTrue);
      await tapTarget('battle-close');
      expect(g.b, isNull);
      // при достатке материи клетка захватывается сразу после победы
      expect(TutStage.values[t.stage], TutStage.build);

      // захваченная клетка остаётся выбранной, поэтому сразу видна кнопка «Развитие»
      expect(g.sel?.own, isTrue);
      await tapTarget('develop');
      expect(find.byKey(const ValueKey('window-cell')), findsOneWidget);
      await tapTarget('build-mine');
      expect(TutStage.values[t.stage], TutStage.fortify);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('tutor-next')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(TutStage.values[t.stage], TutStage.char);

      await tapTarget('menu-char');
      await tapTarget('op-buy');
      expect(g.s.op, greaterThan(0));
      final par = find.textContaining(RegExp(r'^\+\d+ · ')).first;
      await tester.ensureVisible(par);
      await tester.pump();
      await tester.tap(par);
      await tester.pump(const Duration(milliseconds: 100));
      expect(TutStage.values[t.stage], TutStage.tech);

      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pump(const Duration(milliseconds: 400));
      await tapTarget('menu-tech');
      await tapTarget('tech-jump');
      expect(g.hasTech('jump'), isTrue);
      expect(TutStage.values[t.stage], TutStage.time);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(t.rectOf('time'), isNotNull);
      await tester.tap(find.byKey(const ValueKey('tutor-next')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(t.rectOf('jump'), isNotNull);
      await tester.tap(find.byKey(const ValueKey('tutor-next')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(t.done, isTrue);
      expect(find.byKey(const ValueKey('tutor-card')), findsNothing);
    });
  }
}
