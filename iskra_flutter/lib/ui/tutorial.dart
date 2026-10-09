// Обучение новичка: подсказки поверх обычной игры от первого боя до прыжка.
// Шаг засчитывается делом (победа, захват, постройка, вложенное очко, изученная технология),
// пояснения без действия — кнопкой «Понятно». Нужная кнопка подсвечивается рамкой, нужная клетка — на карте.
// Ход обучения хранится на устройстве (iskra-tutor); счётчики шагов берутся из накопительной статистики игры
// с поправкой на значения в момент старта, поэтому повтор обучения снова просит сделать каждое действие.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/game.dart';
import '../l10n/l10n.dart';
import 'panels.dart' show MenuTab;
import 'theme.dart';

/// Шаги обучения по порядку
enum TutStage { win, capture, build, fortify, char, tech, time, jump }

/// Что показать сейчас: текст, подсвеченная кнопка, клетка на карте и кнопка шага-пояснения
class TutView {
  const TutView(this.text, {this.target, this.cell, this.button});
  final String text;

  /// Метка подсвечиваемого элемента интерфейса (см. [Tutor.mark])
  final String? target;

  /// Клетка, которую подсветить на карте
  final String? cell;

  /// Подпись кнопки, если шаг — пояснение без действия
  final String? button;
}

class Tutor {
  Tutor(this.prefs) {
    _load();
  }

  static const prefsKey = 'iskra-tutor';
  static int get total => TutStage.values.length;

  final SharedPreferences prefs;

  /// Номер текущего шага; [total] — обучение пройдено или пропущено
  int stage = 0;

  /// Есть ли запись о ходе обучения на этом устройстве
  bool known = false;

  /// Значения счётчиков в момент старта обучения
  Map<String, double> base = {};

  bool get done => stage >= total;

  final _keys = <String, GlobalKey>{};

  /// Метка элемента для подсветки. Каждую метку ставить только в одном месте экрана
  Widget mark(String id, Widget child) => KeyedSubtree(
    key: _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tut-$id')),
    child: child,
  );

  /// Прямоугольник отмеченного элемента в глобальных координатах, если он сейчас на экране
  Rect? rectOf(String id) {
    final ro = _keys[id]?.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  /// Прокрутить окно так, чтобы отмеченный элемент был виден
  void reveal(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null || Scrollable.maybeOf(ctx) == null) return;
    Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _load() {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      stage = (j['stage'] as num).toInt().clamp(0, total);
      final b = j['base'];
      base = b is Map ? {for (final e in b.entries) '${e.key}': (e.value as num).toDouble()} : {};
      known = true;
    } catch (_) {
      known = false;
    }
  }

  void _save() => prefs.setString(prefsKey, jsonEncode({'stage': stage, 'base': base}));

  static double _charSum(Game g) => g.s.char.values.fold(0, (a, v) => a + v).toDouble();

  /// Начать обучение с первого шага (новая игра или повтор из настроек)
  void start(Game g) {
    stage = 0;
    base = {
      for (final k in ['wins', 'captured', 'built', 'fort']) k: g.stv(k),
      'char': _charSum(g),
    };
    known = true;
    _foeKey = null;
    _save();
  }

  /// Пропустить или завершить обучение
  void finish() {
    stage = total;
    known = true;
    _save();
  }

  /// Шаг-пояснение прочитан
  void next() {
    if (done) return;
    stage++;
    _save();
  }

  /// Игрок давно играет: обучение ему не нужно (прогресс с сервера или старое сохранение)
  static bool veteran(Game g) => g.s.rebirths > 0 || g.stv('wins') >= 3 || g.own.length > 3;

  double _d(Game g, String k) => g.stv(k) - (base[k] ?? 0);

  bool _met(TutStage st, Game g) => switch (st) {
    TutStage.win => _d(g, 'wins') > 0,
    // если свободной клетки не осталось, захватывать нечего — шаг пропускается
    TutStage.capture => _d(g, 'captured') > 0 || (g.b == null && _free(g) == null),
    TutStage.build => _d(g, 'built') > 0,
    TutStage.fortify => _d(g, 'fort') > 0,
    TutStage.char => _charSum(g) > (base['char'] ?? 6),
    TutStage.tech => g.hasTech('jump'),
    TutStage.time || TutStage.jump => false,
  };

  /// Перейти через выполненные шаги. true — шаг сменился
  bool update(Game g) {
    if (!known || done) return false;
    final was = stage;
    while (!done && _met(TutStage.values[stage], g)) {
      stage++;
    }
    if (stage == was) return false;
    _save();
    return true;
  }

  String? _foeKey;
  double _foeAt = -1e9;

  /// Сущность по соседству, которую проще всего победить (прогноз считается не чаще раза в секунду)
  String? _foe(Game g) {
    final cur = g.cell(_foeKey);
    if (cur != null && cur.alive && !cur.own && g.vis.contains(cur.key) && g.now - _foeAt < 1) return _foeKey;
    _foeAt = g.now;
    Cell? best;
    var bp = -1.0;
    final seen = <String>{};
    for (final o in g.own) {
      for (final n in g.neighbors(o)) {
        if (n.own || !n.alive || !seen.add(n.key)) continue;
        final p = g.fightForecast(n).p;
        if (p > bp || (p == bp && best != null && n.might < best.might)) {
          bp = p;
          best = n;
        }
      }
    }
    return _foeKey = best?.key;
  }

  /// Свободная клетка (сущность побеждена), лучше всего — рядом со своими
  String? _free(Game g) {
    String? any;
    for (final key in g.vis) {
      final c = g.cell(key);
      if (c == null || c.own || c.alive) continue;
      if (g.neighbors(c).any((n) => n.own)) return key;
      any ??= key;
    }
    return any;
  }

  /// Своя клетка, на которой можно строить
  static Cell? _ownCell(Game g) {
    final sel = g.sel;
    if (sel != null && sel.own && !sel.spark) return sel;
    for (final c in g.own) {
      if (!c.spark) return c;
    }
    return null;
  }

  /// Подсказка для текущего состояния игры; null — ничего не показывать
  TutView? view(Game g, MenuTab? tab) {
    if (!known || done || !g.s.introSeen) return null;
    final st = TutStage.values[stage], b = g.b;
    if (b != null) {
      // в бою подсказки нужны только до первой победы
      // (и после неё — подсказать закрыть окно боя)
      if (st != TutStage.win && !(b.over && st.index <= TutStage.build.index)) return null;
      if (!b.started && !b.over) {
        return TutView(tx('Это окно боя: сверху сущность, ниже прогноз. Нажмите «Начать бой».'), target: 'battle-start');
      }
      if (!b.over) {
        return TutView(
          tx(
            'Искра бьёт сама, каждый удар стоит немного материи. Способности внизу бьют сильнее: нажимайте их, когда они готовы.',
          ),
          target: 'battle-abil',
        );
      }
      return TutView(
        b.won
            ? tx('Победа! Закройте окно боя.')
            : tx('Не вышло, так бывает. Закройте окно и выберите сущность с прогнозом «вероятная победа» или лучше.'),
        target: 'battle-close',
      );
    }
    final sel = g.sel;
    switch (st) {
      case TutStage.win:
        if (sel != null && !sel.own && sel.alive && tab == null) {
          return TutView(tx('Внизу — сущность и прогноз боя. Нажмите «Атаковать».'), target: 'attack');
        }
        return TutView(
          tx('Нажмите на подсвеченную клетку рядом с искрой: в ней живёт сущность, которую проще всего победить.'),
          cell: _foe(g),
        );
      case TutStage.capture:
        if (sel != null && !sel.own && !sel.alive && tab == null) {
          final lack = g.s.matter < sel.might.ceil();
          return TutView(
            lack
                ? tx('Клетка свободна, но на захват пока не хватает материи. Она копится сама: подождите и нажмите «Захватить».')
                : tx('Клетка свободна. Нажмите «Захватить»: это стоит столько материи, какова мощь клетки.'),
            target: 'capture',
          );
        }
        return TutView(tx('Нажмите на подсвеченную клетку, где жила сущность, чтобы захватить её.'), cell: _free(g));
      case TutStage.build:
        final mine = _ownCell(g);
        if (mine == null) {
          return TutView(tx('Победите сущность рядом с искрой и захватите её клетку, чтобы строить на ней.'), cell: _foe(g));
        }
        if (tab == MenuTab.cell && sel != null && sel.own && !sel.spark) {
          return TutView(
            tx('Нажмите «+» у шахты: она добывает материю. Завод усиливает всю добычу, башня — защиту клетки.'),
            target: 'build-mine',
          );
        }
        if (tab == null && sel == mine) {
          return TutView(tx('Это ваша клетка. Нажмите «Развитие», чтобы строить на ней.'), target: 'develop');
        }
        return TutView(tx('Нажмите на свою новую клетку — она подсвечена на карте.'), cell: mine.key);
      case TutStage.fortify:
        return TutView(
          tx(
            'Клетки тьмы растут. Если мощь соседа догонит защиту вашей клетки, тьма её заберёт. '
            'Кнопка «Укрепить» поднимает защиту, а число в скобках у «Клеток» сверху — сколько клеток под угрозой.',
          ),
          target: tab == null ? 'fortify' : null,
          button: tx('Понятно'),
        );
      case TutStage.char:
        if (tab == MenuTab.char) {
          return g.s.op > 0
              ? TutView(tx('Вложите очки параметров (ОП): нажмите кнопку под любым параметром.'))
              : TutView(tx('Купите очко параметров (ОП) за материю, затем вложите его в любой параметр.'), target: 'op-buy');
        }
        return TutView(
          tx('Материю можно вложить в саму искру, чтобы побеждать сильных сущностей. Откройте «Параметры искры» в меню внизу.'),
          target: 'menu-char',
        );
      case TutStage.tech:
        if (tab == MenuTab.tech) {
          return TutView(
            tx('Изучите «Прыжок»: пульсар на него у вас уже есть. Новые пульсары иногда выпадают за победы и даются за прыжки.'),
            target: 'tech-jump',
          );
        }
        return TutView(tx('Откройте «Технологии»: они изучаются за пульсары и остаются после прыжка.'), target: 'menu-tech');
      case TutStage.time:
        return TutView(
          tx('Кнопки слева внизу ставят паузу и ускоряют время в 2 или 3 раза.'),
          target: tab == null ? 'time' : null,
          button: tx('Понятно'),
        );
      case TutStage.jump:
        return TutView(
          tx(
            'Когда тьма начнёт теснить, нажмите ракету справа вверху. Искра прыгнет в новый мир и получит '
            'постоянный бонус к добыче и бою. Дальше — сами. Удачи!',
          ),
          target: 'jump',
          button: tx('Завершить'),
        );
    }
  }
}

/// Карточка подсказки: шаг, текст, «Пропустить обучение» и кнопка шага-пояснения
class TutorCard extends StatelessWidget {
  const TutorCard({super.key, required this.view, required this.stage, required this.onNext, required this.onSkip});
  final TutView view;
  final int stage;
  final VoidCallback onNext, onSkip;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        key: const ValueKey('tutor-card'),
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 4),
        decoration: BoxDecoration(
          color: const Color(0xF2231C40),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.violet.withValues(alpha: 0.8)),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.school_outlined, size: 18, color: C.violet),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx('Обучение · шаг {n} из {t}', {'n': stage + 1, 't': Tutor.total}),
                        style: const TextStyle(color: C.violet, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(view.text, style: const TextStyle(color: C.ink, fontSize: 13, height: 1.25)),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('tutor-skip'),
                  onPressed: onSkip,
                  style: TextButton.styleFrom(foregroundColor: C.muted, visualDensity: VisualDensity.compact),
                  child: Text(tx('Пропустить обучение'), style: const TextStyle(fontSize: 12)),
                ),
                if (view.button != null)
                  TextButton(
                    key: const ValueKey('tutor-next'),
                    onPressed: onNext,
                    style: TextButton.styleFrom(foregroundColor: C.gold, visualDensity: VisualDensity.compact),
                    child: Text(view.button!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Пульсирующая рамка вокруг подсвеченной кнопки; касания проходят насквозь
class TutorHighlight extends StatefulWidget {
  const TutorHighlight({super.key, required this.tutor, required this.target, required this.repaint});
  final Tutor tutor;
  final String? target;
  final Listenable repaint;

  @override
  State<TutorHighlight> createState() => _TutorHighlightState();
}

class _TutorHighlightState extends State<TutorHighlight> {
  final _self = GlobalKey();
  String? _shown;

  /// Новый подсвеченный элемент один раз прокручивается в поле зрения
  void _revealLater() {
    final id = widget.target;
    if (id == null || id == _shown) return;
    _shown = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.target == id) widget.tutor.reveal(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    _revealLater();
    return IgnorePointer(
      child: CustomPaint(
        key: _self,
        size: Size.infinite,
        painter: _HighlightPainter(widget.tutor, widget.target, _self, widget.repaint),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter(this.tutor, this.target, this.self, Listenable repaint) : super(repaint: repaint);
  final Tutor tutor;
  final String? target;
  final GlobalKey self;

  @override
  void paint(Canvas canvas, Size size) {
    final t = target;
    if (t == null) return;
    final r = tutor.rectOf(t), me = self.currentContext?.findRenderObject();
    if (r == null || me is! RenderBox || !me.attached) return;
    final rect = r.shift(-me.localToGlobal(Offset.zero)).inflate(4);
    final pulse = .5 + .5 * math.sin(DateTime.now().millisecondsSinceEpoch / 1000 * 4);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      rr.inflate(3 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = C.gold.withValues(alpha: .18 * (1 - pulse) + .08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = C.gold.withValues(alpha: .55 + .45 * pulse),
    );
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter old) => true;
}
