// Главный экран: ресурсы сверху, карта, лента сообщений, строка меню внизу.
// Пункты меню открываются окнами поверх карты; строка меню остаётся видна и под окном.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/game.dart';
import '../net/cloud_sync.dart';
import 'controller.dart';
import 'hex_map.dart';
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
  double blockH = 0; // высота блока выбранной клетки: над ним поднимаются кнопки по краям карты

  /// Тень под надписями поверх карты (у верхних строк нет фона)
  static const _shadow = [Shadow(color: Color(0xE6000000), blurRadius: 4)];
  SyncConflict? conflict;
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
      sync.init();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) ctl.onPause();
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
    if (!g.s.introSeen) {
      ctl.act((g) => g.s.introSeen = true);
      return true;
    }
    if (g.b != null) {
      ctl.act((g) => g.closeBattle());
      return true;
    }
    if (ctl.showJump && !ctl.jumpDefeat) {
      ctl.closeJump();
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
    final block = _cellBlock(g);
    final lift = block == null ? 0.0 : blockH + 8;
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
                        Positioned.fill(
                          child: HexMap(ctl: ctl, controlsBottom: lift),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _topBar(g),
                              _header(g),
                              Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 0), child: _feed()),
                            ],
                          ),
                        ),
                        Positioned(left: 8, bottom: 8 + lift, child: _timeColumn(g)),
                        if (block != null)
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 560),
                                child: _MeasureSize(
                                  onChange: (h) {
                                    if (h != blockH) setState(() => blockH = h);
                                  },
                                  child: block,
                                ),
                              ),
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
            if (!g.s.introSeen) IntroOverlay(ctl),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
          res(
            'Клетки',
            '${g.own.length} ($thr)',
            color: thr > 0 ? C.bad : C.ink,
            tip: 'Всего клеток (из них под угрозой)',
          ),
          res('Бонус', '×${Fmt.x(g.bonusMul, 2)}'),
          res('Пульсары', '${g.s.pulsars}', tip: 'Пульсары — валюта технологий'),
        ],
      ),
    );
  }

  /// Картинка эры на кнопке: своя для каждой из 24 эр
  static const _eraIcons = {
    'dawn': Icons.wb_twilight,
    'drain': Icons.water_drop_outlined,
    'tide': Icons.waves,
    'torpor': Icons.ac_unit,
    'flame': Icons.local_fire_department,
    'dim': Icons.brightness_low,
    'blood': Icons.bloodtype_outlined,
    'brittle': Icons.heart_broken_outlined,
    'stone': Icons.landscape_outlined,
    'lore': Icons.menu_book_outlined,
    'toll': Icons.paid_outlined,
    'builders': Icons.construction,
    'scarcity': Icons.remove_shopping_cart_outlined,
    'bastions': Icons.fort,
    'spoils': Icons.card_giftcard,
    'meager': Icons.money_off,
    'starfall': Icons.auto_awesome,
    'void': Icons.blur_on,
    'ancients': Icons.visibility_outlined,
    'bloom': Icons.local_florist_outlined,
    'swift': Icons.bolt,
    'viscous': Icons.hourglass_bottom,
    'balance': Icons.balance,
    'eclipse': Icons.brightness_3_outlined,
  };

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
            Icon(_eraIcons[e.id] ?? Icons.hourglass_empty, size: 22, color: C.kind(e.kind)),
            () => setState(() => tab = MenuTab.era),
            tip: 'Эры',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => tab = MenuTab.era),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.name} · ${l ~/ 60}:${(l % 60).toString().padLeft(2, '0')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: C.kind(e.kind), fontWeight: FontWeight.w700, shadows: shadow),
                  ),
                  Text(
                    e.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.muted, fontSize: 12, shadows: shadow),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
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
                    Text(
                      tr.text.substring(2),
                      style: TextStyle(color: C.kind(tr.kind), fontSize: 12, shadows: shadow),
                    ),
                  ],
                ),
              ],
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
      buttons = [open('Параметры', MenuTab.char)];
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
        ActBtn(
          'Укрепить',
          g.s.matter >= dc ? () => ctl.act((g) => g.fortify(c.key)) : null,
          right: Fmt.n(dc),
          primary: danger,
        ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xF21C1733),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.own ? C.gold.withValues(alpha: 0.4) : C.line),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
          ),
          const SizedBox(width: 8),
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  SizedBox(height: 36, child: buttons[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _tabIcons = {
    MenuTab.cell: Icons.hexagon_outlined,
    MenuTab.char: Icons.person_outline,
    MenuTab.abil: Icons.auto_awesome_outlined,
    MenuTab.art: Icons.diamond_outlined,
    MenuTab.tech: Icons.science_outlined,
    MenuTab.era: Icons.hourglass_empty,
    MenuTab.acc: Icons.account_circle_outlined,
    MenuTab.top: Icons.leaderboard_outlined,
  };

  /// Строка меню внизу экрана: все пункты в один ряд, выбранный подсвечен
  Widget _menu() {
    // «Клетка» открывается из блока выбранной клетки, «Эры» — кнопкой эры слева вверху
    final tabs = [
      MenuTab.char,
      MenuTab.abil,
      MenuTab.art,
      MenuTab.tech,
      if (ctl.sync?.on ?? false) MenuTab.top,
      MenuTab.acc,
    ];
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
          child: Row(
            children: [
              for (final t in tabs)
                Expanded(
                  child: InkWell(
                    key: ValueKey('menu-${t.name}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => tab = tab == t ? null : t),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                      decoration: BoxDecoration(
                        color: tab == t ? C.gold.withValues(alpha: 0.18) : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tabIcons[t], size: 22, color: tab == t ? C.gold : C.muted),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tabTitles[t]!,
                              maxLines: 1,
                              style: TextStyle(fontSize: 11, color: tab == t ? C.ink : C.muted),
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
    );
  }

  /// Окно пункта меню поверх карты; нажатие мимо окна или на крестик закрывает его
  Widget _window(MenuTab t) => Positioned.fill(
    child: GestureDetector(
      onTap: () => setState(() => tab = null),
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
              child: Stack(
                children: [
                  SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 16), child: panelFor(t, ctl)),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton(
                      tooltip: 'Закрыть',
                      icon: const Icon(Icons.close, size: 20, color: C.muted),
                      onPressed: () => setState(() => tab = null),
                    ),
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

/// Сообщает высоту ребёнка после раскладки
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});
  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasure(onChange);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) => renderObject.onChange = onChange;
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onChange);
  ValueChanged<double> onChange;
  double? _h;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _h) return;
    _h = h;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(h));
  }
}
