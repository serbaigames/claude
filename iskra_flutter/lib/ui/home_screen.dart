// Главный экран: ресурсы сверху, карта, лента сообщений, строка меню внизу.
// Пункты меню открываются окнами поверх карты; строка меню остаётся видна и под окном.
import 'dart:async';

import 'package:flutter/material.dart';
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
    ctl.save();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final g = ctl.game;
    final map = Stack(
      children: [
        Positioned.fill(child: HexMap(ctl: ctl)),
        Positioned(left: 8, top: 8, right: 60, child: _feed()),
        Positioned(left: 8, right: 56, bottom: 8, child: _actionBar(g)),
        if (tab != null) _window(tab!),
      ],
    );
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
                  _topBar(g),
                  _eraStrip(g),
                  Expanded(child: map),
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
            Text(label, style: const TextStyle(fontSize: 11, color: C.muted)),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
    final thr = g.threatCount;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(bottom: BorderSide(color: C.line)),
      ),
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

  Widget _eraStrip(Game g) {
    final e = g.eraNow, l = g.s.era!.left.ceil(), tr = g.worldTrend();
    final era = InkWell(
      onTap: () => setState(() => tab = MenuTab.era),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${e.name} · ${l ~/ 60}:${(l % 60).toString().padLeft(2, '0')}',
              style: TextStyle(color: C.kind(e.kind), fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: '  ${e.desc}',
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final trend = Tooltip(
      message: tr.info,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // стрелка из текста ядра (▲ ▼ ■) рисуется значком: такие символы есть не во всех шрифтах
          Icon(
            tr.kind == 'grow'
                ? Icons.arrow_upward
                : tr.kind == 'stall'
                ? Icons.stop
                : Icons.arrow_downward,
            size: 14,
            color: C.kind(tr.kind),
          ),
          const SizedBox(width: 4),
          Text(tr.text.substring(2), style: TextStyle(color: C.kind(tr.kind), fontSize: 12)),
        ],
      ),
    );
    final time = [
      _timeBtn(
        Icon(g.s.paused ? Icons.play_arrow : Icons.pause, size: 16),
        () => ctl.setPaused(!g.s.paused),
        g.s.paused,
      ),
      for (final s in [1, 2, 3])
        _timeBtn(Text('×$s', style: const TextStyle(fontSize: 12)), () => ctl.setSpeed(s), g.speed == s),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: C.bg,
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 640
            ? Row(
                children: [
                  Expanded(child: era),
                  trend,
                  const SizedBox(width: 8),
                  ...time,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  era,
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: trend),
                      ...time,
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _timeBtn(Widget child, VoidCallback f, bool on) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: SizedBox(
      height: 30,
      child: FilledButton(
        onPressed: f,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(34, 30),
          backgroundColor: on ? C.goldBg : C.btn,
          foregroundColor: on ? C.gold : C.ink,
        ),
        child: child,
      ),
    ),
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

  /// Быстрое действие для выбранной клетки (actbar в веб-версии)
  Widget _actionBar(Game g) {
    final c = g.sel;
    if (c == null || c.spark) return const SizedBox.shrink();
    Widget bar(List<Widget> children) => Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xE61C1733),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Row(children: children),
    );
    if (c.own) {
      final def = g.cellDef(c), th = g.maxAdjMight(c), danger = th >= def * 0.8, dc = g.defCost(c);
      return bar([
        Expanded(
          child: Text(
            '🛡 ${Fmt.n(def.floor())} · ${danger ? 'угроза' : 'защищена'}${th > 0 ? ' · сосед ${Fmt.n(th.ceil())}' : ''}',
            style: TextStyle(color: danger ? C.bad : C.ok),
          ),
        ),
        ActBtn(
          'Укрепить',
          g.s.matter >= dc ? () => ctl.act((g) => g.fortify(c.key)) : null,
          right: Fmt.n(dc),
          primary: danger,
        ),
      ]);
    }
    if (!c.alive) {
      final cost = c.might.ceil();
      return bar([
        const Expanded(child: Text('Свободная клетка')),
        ActBtn(
          'Захватить',
          g.s.matter >= cost ? () => ctl.act((g) => g.capture(c.key)) : null,
          right: Fmt.n(cost),
          primary: true,
        ),
      ]);
    }
    final fc = g.fightForecast(c), lab = GameForecast.forecastLabel(fc.p);
    return bar([
      Expanded(
        child: Text(lab.label, style: TextStyle(color: C.kind(lab.kind))),
      ),
      ActBtn('В бой', () => ctl.act((g) => g.startBattle(g.foeFromCell(c), c.key)), primary: true),
    ]);
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
    final tabs = [
      for (final t in MenuTab.values)
        if ((t != MenuTab.top) || (ctl.sync?.on ?? false)) t,
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
