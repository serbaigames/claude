// Главный экран: ресурсы сверху, карта, лента сообщений, строка меню внизу.
// Пункты меню открываются окнами поверх карты; строка меню остаётся видна и под окном.
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/game.dart';
import '../net/cloud_sync.dart';
import 'controller.dart';
import 'gfx.dart';
import 'hex_map.dart';
import 'icons.dart';
import 'overlays.dart';
import 'panels.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.ctl});
  final GameController ctl;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  MenuTab? tab;

  /// Тень под надписями поверх карты (у верхних строк нет фона)
  static const _shadow = [Shadow(color: Color(0xE6000000), blurRadius: 4)];
  SyncConflict? conflict;

  /// Гость без учётной записи: при каждом запуске предлагаем войти или зарегистрироваться
  bool guestAsk = false;
  Completer<bool>? _conflictDone;

  GameController get ctl => widget.ctl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      ctl.tick(dt);
    })..start();
    ctl.addListener(_changed);
    final sync = ctl.sync;
    if (sync != null) {
      sync.askConflict = (c) {
        _conflictDone = Completer<bool>();
        setState(() => conflict = c);
        return _conflictDone!.future;
      };
      sync.init().then((_) {
        if (mounted && sync.on && sync.user == null) setState(() => guestAsk = true);
      });
    }
  }

  void _changed() {
    // выбор клетки для артефакта: окно меню закрывается, видна карта
    if (ctl.artPick != null) tab = null;
    // начался бой: окно клетки под ним больше не нужно
    if (ctl.game.b != null) tab = null;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) ctl.onPause();
    if (state == AppLifecycleState.resumed) ctl.sound.setAppPaused(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ctl.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  /// Системная кнопка «Назад»: закрывает окна и меню (window.iskraBack в веб-версии)
  bool _back() {
    final g = ctl.game;
    if (conflict != null) return true;
    if (guestAsk && g.s.introSeen) {
      setState(() => guestAsk = false);
      return true;
    }
    if (!g.s.introSeen) {
      ctl.act((g) => g.s.introSeen = true);
      return true;
    }
    if (g.b != null) {
      ctl.act((g) => g.closeBattle());
      return true;
    }
    if (ctl.showEra) {
      ctl.closeEra();
      return true;
    }
    if (ctl.showJump && !ctl.jumpDefeat) {
      ctl.closeJump();
      return true;
    }
    if (ctl.artPick != null) {
      ctl.cancelArtPick();
      return true;
    }
    if (tab != null) {
      setState(() => tab = null);
      return true;
    }
    if (g.sel != null) {
      ctl.select(null);
      return true;
    }
    ctl.save();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final g = ctl.game;
    final block = ctl.artPick != null ? _artPickBlock(g) : _cellBlock(g);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_back()) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: HexMap(ctl: ctl)),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // лёгкое размытие карты под верхними строками, чтобы текст читался
                              // (при среднем и лёгком качестве — без размытия, фон чуть плотнее)
                              ClipRect(
                                child: BackdropFilter(
                                  enabled: Gfx.backdrop,
                                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: Gfx.backdrop
                                            ? const [Color(0x8C0B0816), Color(0x260B0816)]
                                            : const [Color(0xC00B0816), Color(0x4D0B0816)],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [_topBar(g), _header(g)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 0), child: _feed()),
                            ],
                          ),
                        ),
                        Positioned(left: 8, bottom: 8, child: _timeColumn(g)),
                        if (block != null)
                          // блок между столбиками кнопок времени (слева) и масштаба (справа), кнопки не сдвигает
                          Positioned(
                            left: 56,
                            right: 56,
                            bottom: 8,
                            child: Center(
                              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: block),
                            ),
                          ),
                        if (tab != null) _window(tab!),
                      ],
                    ),
                  ),
                  _menu(),
                ],
              ),
            ),
            if (g.def != null && g.b == null) DefendOverlay(ctl),
            if (g.b != null) BattleOverlay(ctl),
            if (ctl.showJump) JumpOverlay(ctl),
            if (ctl.showEra && g.b == null && g.def == null && !ctl.showJump && g.s.introSeen) EraOverlay(ctl),
            if (!g.s.introSeen) IntroOverlay(ctl),
            if (guestAsk && g.s.introSeen && conflict == null && g.b == null && !ctl.showJump) _guestOverlay(),
            if (conflict != null)
              ConflictOverlay(ctl, conflict!, (v) {
                setState(() => conflict = null);
                _conflictDone?.complete(v);
              }),
          ],
        ),
      ),
    );
  }

  Widget _guestOverlay() => Overlay2(
    key: const ValueKey('guest-ask'),
    onClose: () => setState(() => guestAsk = false),
    maxWidth: 420,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.account_circle_outlined, size: 44, color: C.violet),
        const SizedBox(height: 8),
        Text('Вы играете без учётной записи', style: h2(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Прогресс хранится только на этом устройстве. Войдите или зарегистрируйтесь, чтобы сохранять его на сервере, '
          'продолжать игру на другом устройстве и попасть в рейтинги.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        ActBtn(
          'Войти или зарегистрироваться',
          () => setState(() {
            guestAsk = false;
            tab = MenuTab.acc;
          }),
          primary: true,
        ),
        const SizedBox(height: 6),
        ActBtn('Играть без входа', () => setState(() => guestAsk = false)),
      ],
    ),
  );

  Widget _topBar(Game g) {
    Widget res(String label, String value, {Color color = C.ink, String? tip}) => Expanded(
      child: Tooltip(
        message: tip ?? label,
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: C.muted, shadows: _shadow),
            ),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w700, color: color, shadows: _shadow),
              ),
            ),
          ],
        ),
      ),
    );
    final thr = g.threatCount;
    // показатели собраны к центру, по бокам широкого экрана остаётся пустое поле
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            children: [
              res('Материя', Fmt.n(g.s.matter), color: C.gold),
              res(
                'Добыча',
                g.s.paused ? 'пауза' : '+${Fmt.n1(g.income())}/с',
                color: g.s.paused ? C.muted : C.ok,
                tip: 'Суммарная добыча материи в секунду',
              ),
              res(
                'Заводы',
                '+${Fmt.n1(g.incomeParts().fac)}%',
                tip: 'Бонус заводов ко всей добыче: сумма процентов всех заводов ÷ число клеток',
              ),
              res('Клетки', '${g.own.length} ($thr)', color: thr > 0 ? C.bad : C.ink, tip: 'Всего клеток (из них под угрозой)'),
              res('Бонус', '×${Fmt.x(g.bonusMul, 2)}'),
              res('Пульсары', '${g.s.pulsars}', tip: 'Пульсары — валюта технологий'),
            ],
          ),
        ),
      ),
    );
  }

  /// Круглая кнопка в стиле кнопок масштаба карты
  Widget _sqBtn(Widget child, VoidCallback f, {bool on = false, String? tip}) {
    final b = SizedBox(
      width: 40,
      height: 40,
      child: FilledButton(
        onPressed: f,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: on ? C.goldBg : null,
          foregroundColor: on ? C.gold : null,
        ),
        child: child,
      ),
    );
    return tip == null ? b : Tooltip(message: tip, child: b);
  }

  /// Вторая строка сверху: эра слева, прыжок справа
  Widget _header(Game g) {
    final e = g.eraNow, l = g.s.era!.left.ceil(), tr = g.worldTrend();
    final jump = g.hasTech('jump');
    const shadow = _shadow;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sqBtn(
            Icon(eraIcons[e.id] ?? Icons.hourglass_empty, size: 22, color: C.kind(e.kind)),
            () => setState(() => tab = MenuTab.era),
            tip: 'Эры',
          ),
          const SizedBox(width: 8),
          // эре — больше места; длинный прогноз справа переносится, а не сжимает название эры
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: () => setState(() => tab = MenuTab.era),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // название эры может перенестись, таймер всегда целиком
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          e.name,
                          style: TextStyle(color: C.kind(e.kind), fontWeight: FontWeight.w700, shadows: shadow),
                        ),
                      ),
                      Text(
                        ' · ${l ~/ 60}:${(l % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(color: C.kind(e.kind), fontWeight: FontWeight.w700, shadows: shadow),
                      ),
                    ],
                  ),
                  Text(
                    e.desc,
                    style: const TextStyle(color: C.muted, fontSize: 12, shadows: shadow),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: Tooltip(
              message: tr.info,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${Fmt.x(g.rebirthGain(), 2)} к бонусу',
                    style: TextStyle(color: jump ? C.gold : C.muted, fontWeight: FontWeight.w700, shadows: shadow),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // стрелка из текста ядра (▲ ▼ ■) рисуется значком: такие символы есть не во всех шрифтах
                      Icon(
                        tr.kind == 'grow'
                            ? Icons.arrow_upward
                            : tr.kind == 'stall'
                            ? Icons.stop
                            : Icons.arrow_downward,
                        size: 13,
                        color: C.kind(tr.kind),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          tr.text.substring(2),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: C.kind(tr.kind), fontSize: 12, shadows: shadow),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sqBtn(
            Icon(Icons.rocket_launch_outlined, size: 20, color: jump ? C.gold : C.muted),
            () => jump ? ctl.openJump() : setState(() => tab = MenuTab.tech),
            tip: jump ? 'Прыжок искры' : 'Прыжок: нужна технология',
          ),
        ],
      ),
    );
  }

  /// Пауза и скорость времени: столбик слева внизу, как кнопки масштаба справа
  Widget _timeColumn(Game g) => Column(
    children: [
      _sqBtn(
        Icon(g.s.paused ? Icons.play_arrow : Icons.pause, size: 20),
        () => ctl.setPaused(!g.s.paused),
        on: g.s.paused,
        tip: g.s.paused ? 'Продолжить' : 'Пауза',
      ),
      for (final s in [1, 2, 3]) ...[
        const SizedBox(height: 6),
        _sqBtn(
          Text('×$s', style: const TextStyle(fontSize: 13)),
          () => ctl.setSpeed(s),
          on: !g.s.paused && g.speed == s,
          tip: 'Скорость ×$s',
        ),
      ],
    ],
  );

  Widget _feed() {
    final now = DateTime.now();
    final items = ctl.feed.where((f) => now.difference(f.at).inSeconds < 7).take(4).toList();
    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in items)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xD91C1733), borderRadius: BorderRadius.circular(8)),
              child: Text(f.text, style: TextStyle(fontSize: 13, color: f.kind == 'info' ? C.ink : C.kind(f.kind))),
            ),
        ],
      ),
    );
  }

  /// Подсказка при применении артефакта: какую клетку выбрать
  Widget _artPickBlock(Game g) {
    final i = ctl.artPick!;
    if (i >= g.s.artifacts.length) return const SizedBox.shrink();
    final a = g.s.artifacts[i], d = Defs.arts[a.type]!;
    final what = switch (d.target) {
      'spark' => 'искру',
      'own' => 'свою клетку',
      _ => 'клетку тьмы',
    };
    return Container(
      key: const ValueKey('art-pick'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xF21C1733),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(d.color).withValues(alpha: 0.7)),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              artIcon(a.type, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.artTitle(a),
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(d.color)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Выберите на карте $what — артефакт применится к ней.', style: const TextStyle(color: C.ink, fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(height: 34, child: ActBtn('Отмена', ctl.cancelArtPick)),
        ],
      ),
    );
  }

  /// Блок выбранной клетки над меню: сущность, свободная клетка, своя клетка или искра
  Widget? _cellBlock(Game g) {
    final c = g.sel;
    if (c == null) return null;
    Widget open(String label, MenuTab t) => ActBtn(label, () => setState(() => tab = t));
    Widget line(String text, {Color color = C.muted, double size = 13, FontWeight? w}) => Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: size, fontWeight: w),
    );
    final String title;
    Widget? chip;
    final List<Widget> info, buttons;
    if (c.spark) {
      final x = g.incomeParts();
      title = 'Искра';
      info = [
        line('+${Fmt.n1(x.base)} материи/с · ядро ×${g.coreMul}', color: C.ok),
        line('бонус прыжка ×${Fmt.x(g.bonusMul, 2)} · искру нельзя потерять'),
      ];
      buttons = [open('Статистика', MenuTab.world)];
    } else if (c.own) {
      final def = g.cellDef(c), th = g.maxAdjMight(c), danger = th >= def * 0.8, dc = g.defCost(c);
      final lv = Game.cellLvl(c);
      title = 'Ваша клетка · ур. $lv';
      info = [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 15, color: danger ? C.bad : C.ok),
            const SizedBox(width: 4),
            Flexible(
              child: line(
                '${Fmt.n(def.floor())} · ${danger ? 'угроза' : 'защищена'}${th > 0 ? ' · сосед ${Fmt.n(th.ceil())}' : ''}',
                color: danger ? C.bad : C.ok,
              ),
            ),
          ],
        ),
        line(
          'материя ${g.st(c, 'm').round()}% · энергия ${g.st(c, 'e').round()}% · сила ${g.st(c, 'f').round()}%'
          ' · строения ${Game.usedCap(c)} из ${Game.cap(c)}',
          size: 12,
        ),
      ];
      buttons = [
        ActBtn('Укрепить', g.s.matter >= dc ? () => ctl.act((g) => g.fortify(c.key)) : null, right: Fmt.n(dc), primary: danger),
        open('Развитие', MenuTab.cell),
      ];
    } else if (!c.alive) {
      final cost = c.might.ceil(), lack = g.s.matter < cost;
      title = 'Свободная клетка';
      info = [
        line(
          lack ? 'нужно ещё ${Fmt.n((cost - g.s.matter).ceil())} материи' : 'защитник побеждён, можно взять',
          color: lack ? C.bad : C.ok,
        ),
      ];
      buttons = [
        ActBtn('Захватить', lack ? null : () => ctl.act((g) => g.capture(c.key)), right: Fmt.n(cost), primary: true),
        open('Клетка', MenuTab.cell),
      ];
    } else {
      final f = g.foeFromCell(c), fc = g.fightForecast(c), lab = GameForecast.forecastLabel(fc.p);
      title = f.name;
      chip = tierChip(c.tier, Defs.tiers[c.tier]!.name);
      info = [
        line('${lab.label} · ${(fc.p * 100).round()}%', color: C.kind(lab.kind), size: 14, w: FontWeight.w700),
        line('мощь ${Fmt.n(c.might.ceil())} · ${g.fcMatter(fc)}', size: 12),
      ];
      buttons = [
        ActBtn('Атаковать', () => ctl.act((g) => g.startBattle(g.foeFromCell(c), c.key)), primary: true),
        open('Клетка', MenuTab.cell),
      ];
    }
    return Container(
      key: const ValueKey('cell-block'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xF21C1733),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.own ? C.gold.withValues(alpha: 0.4) : C.line),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.own ? C.gold : C.ink),
                    ),
                  ),
                  if (chip != null) ...[const SizedBox(width: 6), chip],
                ],
              ),
              const SizedBox(height: 2),
              ...info,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: SizedBox(height: 34, child: buttons[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static const _tabIcons = {
    MenuTab.cell: Icons.hexagon_outlined,
    MenuTab.char: Icons.radar,
    MenuTab.abil: Icons.auto_awesome_outlined,
    MenuTab.art: Icons.diamond_outlined,
    MenuTab.tech: Icons.science_outlined,
    MenuTab.era: Icons.hourglass_empty,
    MenuTab.acc: Icons.settings_outlined,
    MenuTab.top: Icons.leaderboard_outlined,
    MenuTab.world: Icons.insights_outlined,
  };

  /// Строка меню внизу экрана: все пункты в один ряд, выбранный подсвечен
  Widget _menu() {
    // «Клетка» открывается из блока выбранной клетки, «Эры» — кнопкой эры слева вверху
    final tabs = [MenuTab.char, MenuTab.abil, MenuTab.art, MenuTab.tech, if (ctl.sync?.on ?? false) MenuTab.top, MenuTab.acc];
    return Container(
      key: const ValueKey('menu-bar'),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in tabs)
                  Expanded(
                    child: InkWell(
                      key: ValueKey('menu-${t.name}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (ctl.artPick != null) ctl.cancelArtPick();
                        ctl.sound.play(tab == t ? 'close' : 'open');
                        setState(() => tab = tab == t ? null : t);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: tab == t ? C.gold.withValues(alpha: 0.18) : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_tabIcons[t], size: 22, color: tab == t ? C.gold : C.muted),
                            const SizedBox(height: 2),
                            // у всех пунктов один размер шрифта и равная ширина; длинные подписи — в две строки
                            Text(
                              t == MenuTab.char ? 'Параметры\nискры' : tabTitles[t]!,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.15,
                                letterSpacing: -0.1,
                                color: tab == t ? C.ink : C.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeWindow() {
    ctl.sound.play('close');
    setState(() => tab = null);
  }

  /// Окно пункта меню поверх карты; нажатие мимо окна или на крестик закрывает его
  Widget _window(MenuTab t) => Positioned.fill(
    child: GestureDetector(
      onTap: _closeWindow,
      child: ColoredBox(
        color: const Color(0x99080514),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              key: ValueKey('window-${t.name}'),
              constraints: const BoxConstraints(maxWidth: 560),
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: C.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.line),
                boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 18)],
              ),
              // крестик отдельной строкой сверху, чтобы не наезжать на кнопки в заголовке окна
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 34,
                    child: IconButton(
                      tooltip: 'Закрыть',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, size: 20, color: C.muted),
                      onPressed: _closeWindow,
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 16), child: panelFor(t, ctl)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
