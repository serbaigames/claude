// Окно «Настройки»: вкладки сверху (как в рейтингах), под ними разделы выбранной вкладки.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/game.dart';
import '../l10n/l10n.dart';
import '../shop/shop.dart';
import '../version.dart';
import 'controller.dart';
import 'gfx.dart';
import 'panels.dart';
import 'portraits.dart';
import 'skins.dart';
import 'sound.dart';
import 'theme.dart';
import 'tutorial.dart';
import 'widgets.dart';

enum SetTab { acc, app, shop, stats, about, dev }

const _setTabs = {
  SetTab.acc: ('Аккаунт', Icons.account_circle_outlined),
  SetTab.app: ('Приложение', Icons.tune),
  SetTab.shop: ('Магазин', Icons.storefront_outlined),
  SetTab.stats: ('Статистика', Icons.insights_outlined),
  SetTab.about: ('Об игре', Icons.info_outline),
  SetTab.dev: ('Развитие', Icons.favorite_border),
};

class SettingsPanel extends StatefulWidget {
  const SettingsPanel(this.ctl, {super.key});
  final GameController ctl;
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  SetTab tab = SetTab.acc;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Настройки'), style: h2()),
        const SizedBox(height: 8),
        _bar(),
        const SizedBox(height: 12),
        switch (tab) {
          SetTab.acc => AccountPanel(ctl),
          SetTab.app => AppSettings(ctl),
          SetTab.shop => ShopView(ctl),
          SetTab.stats => StatsView(ctl.game),
          SetTab.about => const AboutView(),
          SetTab.dev => const SupportView(),
        },
      ],
    );
  }

  /// Все вкладки в одну строку: значок и подпись, выбранная подсвечена
  Widget _bar() => Container(
    key: const ValueKey('settings-tabs'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: C.line),
    ),
    padding: const EdgeInsets.all(3),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in SetTab.values)
            Expanded(
              child: InkWell(
                key: ValueKey('set-${t.name}'),
                borderRadius: BorderRadius.circular(9),
                onTap: () {
                  if (t != tab) widget.ctl.sound.play('tap');
                  setState(() => tab = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: tab == t ? C.gold.withValues(alpha: 0.18) : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_setTabs[t]!.$2, size: 18, color: tab == t ? C.gold : C.muted),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t == SetTab.dev && isEn ? 'Project' : tx(_setTabs[t]!.$1),
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
  );
}

/// Заголовок раздела внутри вкладки
Widget _head(String t, IconData icon) => Padding(
  padding: const EdgeInsets.only(top: 6, bottom: 6),
  child: Row(
    children: [
      Icon(icon, size: 18, color: C.gold),
      const SizedBox(width: 6),
      Expanded(child: Text(t, style: h2())),
    ],
  ),
);

/// Блок-карточка раздела
Widget _card(List<Widget> children, {Color border = C.line, EdgeInsets padding = const EdgeInsets.all(10)}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  // Material, а не Container: переключатели и раскрывающиеся строки рисуют на нём отклик касания
  child: Material(
    color: C.bg.withValues(alpha: 0.45),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  ),
);

/* ---------- приложение: графика и звук ---------- */
class AppSettings extends StatelessWidget {
  const AppSettings(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final snd = ctl.sound;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(tx('Язык'), Icons.translate),
        _card([
          SegmentedButton<Lang>(
            key: const ValueKey('lang'),
            showSelectedIcon: false,
            segments: [for (final l in Lang.values) ButtonSegment(value: l, label: Text(l.title))],
            selected: {lang},
            onSelectionChanged: (v) => ctl.setLang(v.first),
          ),
        ]),
        _head(tx('Обучение'), Icons.school_outlined),
        _card([
          Text(
            ctl.tutor.done
                ? tx('Обучение пройдено. Его можно пройти ещё раз: подсказки покажут каждый шаг с первого боя до прыжка.')
                : tx('Идёт обучение: шаг {n} из {t}.', {'n': ctl.tutor.stage + 1, 't': Tutor.total}),
            style: const TextStyle(color: C.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ActBtn(tx('Пройти обучение заново'), ctl.tutorRestart, key: const ValueKey('tutor-restart')),
        ]),
        _head(tx('Графика и производительность'), Icons.speed),
        _card([
          SegmentedButton<GfxLevel>(
            key: const ValueKey('gfx'),
            showSelectedIcon: false,
            segments: [
              for (final l in GfxLevel.values)
                ButtonSegment(
                  value: l,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx(gfxNames[l]!))),
                ),
            ],
            selected: {ctl.gfx},
            onSelectionChanged: (v) => ctl.setGfx(v.first),
          ),
          const SizedBox(height: 6),
          Text(tx(gfxInfo[ctl.gfx]!), style: const TextStyle(color: C.muted, fontSize: 13)),
          if (kIsWeb)
            Text(
              tx('Чёткость изображения в браузере меняется после перезагрузки страницы.'),
              style: TextStyle(color: C.muted, fontSize: 12),
            ),
        ]),
        _head(tx('Масштаб интерфейса'), Icons.zoom_out_map),
        _card([
          SegmentedButton<bool>(
            key: const ValueKey('ui-scale'),
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: false, label: Text('×1')),
              ButtonSegment(value: true, label: Text(tx('Авто (сейчас ×{x})', {'x': Fmt.x(_autoNow(context), 2)}))),
            ],
            selected: {ctl.uiAuto.value},
            onSelectionChanged: (v) => ctl.setUiAuto(v.first),
          ),
          const SizedBox(height: 6),
          Text(
            tx(
              'Авто увеличивает кнопки, значки и текст на больших экранах и мониторах по размеру окна. '
              'На телефоне масштаб остаётся ×1.',
            ),
            style: TextStyle(color: C.muted, fontSize: 13),
          ),
        ]),
        _head(tx('Звук'), Icons.volume_up_outlined),
        ListenableBuilder(
          listenable: snd,
          builder: (context, _) => _card([
            _slider('vol-master', Icons.volume_up, tx('Общая громкость'), snd.master, snd.setMaster),
            _slider('vol-music', Icons.music_note, tx('Музыка'), snd.music, snd.setMusic),
            _slider('vol-sfx', Icons.graphic_eq, tx('Звуки и эффекты'), snd.effects, snd.setEffects),
            SwitchListTile(
              key: const ValueKey('battle-music'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: snd.battleMusic,
              onChanged: snd.setBattleMusic,
              title: Text(tx('Боевая тема во время боя')),
            ),
            const Divider(color: C.line, height: 12),
            Row(
              children: [
                const Icon(Icons.album_outlined, size: 18, color: C.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    snd.nowPlaying == null
                        ? tx('Музыка начнётся после первого касания')
                        : tx('Играет: «{t}»', {'t': tx(snd.nowPlaying!.name)}),
                    style: const TextStyle(color: C.muted),
                  ),
                ),
                TextButton.icon(
                  onPressed: snd.nowPlaying == null || snd.nowPlaying == battleTrack ? null : snd.nextTrack,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: Text(tx('Дальше')),
                ),
              ],
            ),
            Text(
              tx('Мелодии: {list} и боевая «{b}».', {
                'list': ambientTracks.map((t) => '«${tx(t.name)}»').join(', '),
                'b': tx(battleTrack.name),
              }),
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
          ]),
        ),
      ],
    );
  }

  /// Авто-масштаб по настоящему размеру окна (MediaQuery внутри уже уменьшен)
  double _autoNow(BuildContext context) {
    final v = View.of(context);
    return autoUiScale(v.physicalSize / v.devicePixelRatio);
  }

  Widget _slider(String key, IconData icon, String label, double v, void Function(double) set) => Row(
    children: [
      Icon(v <= 0 ? Icons.volume_off : icon, size: 18, color: v <= 0 ? C.muted : C.gold),
      const SizedBox(width: 6),
      SizedBox(width: 112, child: Text(label)),
      Expanded(
        child: Slider(key: ValueKey(key), value: v, divisions: 20, onChanged: set),
      ),
      SizedBox(
        width: 40,
        child: Text(
          '${(v * 100).round()}%',
          textAlign: TextAlign.right,
          style: const TextStyle(color: C.muted),
        ),
      ),
    ],
  );
}

/* ---------- статистика ---------- */
class StatsView extends StatelessWidget {
  const StatsView(this.g, {super.key});
  final Game g;

  @override
  Widget build(BuildContext context) {
    final s = g.s, k = s.kills;
    final battles = g.stv('battles'), wins = g.stv('wins');
    final era = s.era == null ? null : Defs.eras[s.era!.i];
    final killSum = k.values.fold<int>(0, (a, b) => a + b);
    final points = (k['low'] ?? 0) + 3 * (k['rare'] ?? 0) + 10 * (k['epic'] ?? 0) + 500 * (k['legend'] ?? 0);
    final techs = s.tech.values.fold<int>(0, (a, b) => a + b);
    return Column(
      key: const ValueKey('stats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(tx('Этот мир'), Icons.public),
        _card([
          KV([
            (tx('Время в мире'), Fmt.time(s.worldTime)),
            (tx('Клеток сейчас / максимум'), '${g.own.length} / ${s.worldMax}'),
            (tx('Доход'), tx('{n} материи/с', {'n': Fmt.n1(g.income())})),
            (tx('Добыто материи'), Fmt.n(s.we)),
            (tx('Побед в этом мире'), '${s.wk}'),
            (tx('Агрессивность'), g.aggrText),
            if (era != null) (tx('Эра'), tx('«{e}», ещё {t}', {'e': era.name, 't': Fmt.clock(s.era!.left)})),
          ]),
        ]),
        _head(tx('Сражения'), Icons.flash_on),
        _card([
          KV([
            (tx('Боёв начато'), Fmt.n(battles)),
            (tx('Победы / поражения / отступления'), '${Fmt.n(wins)} / ${Fmt.n(g.stv('losses'))} / ${Fmt.n(g.stv('fled'))}'),
            (tx('Доля побед'), battles > 0 ? '${(wins / battles * 100).round()}%' : '—'),
            (tx('Урон нанесён / получен'), '${Fmt.n(g.stv('dmg'))} / ${Fmt.n(g.stv('taken'))}'),
            (tx('Сильнейший удар'), Fmt.n(g.stv('maxHit'))),
            (tx('Применено способностей'), Fmt.n(g.stv('abil'))),
          ]),
          const SizedBox(height: 8),
          Text(
            tx('Побеждено сущностей: {k}, очков рейтинга: {p}', {'k': killSum, 'p': Fmt.n(points)}),
            style: const TextStyle(color: C.muted),
          ),
          const SizedBox(height: 6),
          for (final t in ['low', 'rare', 'epic', 'legend']) _killBar(t, k[t] ?? 0, killSum),
        ]),
        _head(isEn ? 'Progress' : 'Развитие', Icons.hexagon_outlined),
        _card([
          KV([
            (tx('Клеток захвачено / потеряно'), '${Fmt.n(g.stv('captured'))} / ${Fmt.n(g.stv('lost'))}'),
            (tx('Построено строений'), Fmt.n(g.stv('built'))),
            (tx('Укреплений'), Fmt.n(g.stv('fort'))),
            (tx('Применено артефактов'), Fmt.n(g.stv('arts'))),
            (tx('Артефактов в запасе'), '${s.artifacts.length}'),
            (tx('Рангов технологий'), '$techs'),
            (tx('Пульсары'), '${s.pulsars}'),
          ]),
        ]),
        _head(tx('За всё время'), Icons.emoji_events_outlined),
        _card([
          KV([
            (tx('Материя за всё время'), Fmt.n(s.earned)),
            (tx('Рекорд клеток'), '${s.bestCells}'),
            (tx('Прыжков'), '${s.rebirths}'),
            (tx('Бонус прыжка'), '+${Fmt.x(s.bonus * 100, 0)}%'),
            (tx('Самый долгий мир'), Fmt.time(g.stv('longWorld'))),
            (tx('Время в игре'), Fmt.time(g.stv('play'))),
          ]),
        ]),
        Text(
          tx('Бои, захваты, урон и время в игре считаются с версии 0.4.0.'),
          style: const TextStyle(color: C.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _killBar(String tier, int n, int sum) {
    final col = Color(Defs.tierColor[tier]!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(Defs.tiers[tier]!.name, style: TextStyle(color: col)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: sum == 0 ? 0 : n / sum, minHeight: 8, color: col, backgroundColor: C.line),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              Fmt.n(n),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- об игре ---------- */
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _card([
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: C.gold, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(tx('Искра'), style: h2(C.gold))),
            Container(
              key: const ValueKey('app-version'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.goldBg, borderRadius: BorderRadius.circular(8)),
              child: Text(
                tx('версия {v}', {'v': appVersion}),
                style: const TextStyle(color: C.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tx(
            'Маленькая искра во тьме бесконечного мира шестигранников. Захватывайте клетки, развивайте их, '
            'сражайтесь с сущностями тьмы, собирайте способности и артефакты, изучайте технологии и совершайте прыжки '
            'в новые области вселенной — каждый следующий мир сложнее, но и искра сильнее.',
          ),
        ),
      ]),
      _head(tx('История выпусков'), Icons.history),
      for (final (i, r) in releases.indexed)
        _card(padding: EdgeInsets.zero, border: i == 0 ? C.gold.withValues(alpha: 0.6) : C.line, [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: ValueKey('rel-${r.version}'),
              initiallyExpanded: i == 0,
              tilePadding: const EdgeInsets.symmetric(horizontal: 10),
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              title: Text(
                i == 0 ? tx('Версия {v} — текущая', {'v': r.version}) : tx('Версия {v}', {'v': r.version}),
                style: TextStyle(fontWeight: FontWeight.w700, color: i == 0 ? C.gold : C.ink),
              ),
              subtitle: Text(r.date, style: const TextStyle(color: C.muted, fontSize: 12)),
              children: [
                for (final c in r.changes)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 8),
                          child: Icon(Icons.circle, size: 5, color: C.gold),
                        ),
                        Expanded(child: Text(c)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ]),
    ],
  );
}

/* ---------- магазин: ускорение, стили, поддержка автора ---------- */
class ShopView extends StatelessWidget {
  const ShopView(this.ctl, {super.key});
  final GameController ctl;

  @override
  Widget build(BuildContext context) {
    final shop = ctl.shop;
    final left = shop.boostLeft;
    String price(String id) => shop.prices[id] == null ? '' : ' · ${shop.prices[id]}';
    final canBuy = shop.unavailable == null && !shop.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(tx('Ускорение добычи'), Icons.bolt),
        _card([
          Text(tx('Добыча материи ×{m} на {t} минут.', {'m': boostMul.toInt(), 't': boostTime.inMinutes})),
          const SizedBox(height: 8),
          if (shop.boosted)
            Text(
              tx('Действует ещё {t}', {'t': '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}'}),
              key: const ValueKey('boost-left'),
              style: const TextStyle(color: C.ok, fontWeight: FontWeight.w700),
            )
          else if (shop.supporter || shop.ads != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('boost'),
                onPressed: shop.canBoost ? ctl.boost : null,
                icon: Icon(shop.supporter ? Icons.bolt : Icons.ondemand_video),
                label: Text(shop.supporter ? tx('Включить') : tx('Смотреть видео')),
              ),
            )
          else
            Text(tx('Видео за ускорение есть в версии для Android.'), style: const TextStyle(color: C.muted)),
        ]),
        _head(tx('Стили Искры'), Icons.palette_outlined),
        if (shop.unavailable != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tx(shop.unavailable!),
              key: const ValueKey('shop-unavailable'),
              style: const TextStyle(color: C.muted),
            ),
          ),
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 640 ? 2 : 1, w = (box.maxWidth - 10 * (cols - 1)) / cols;
            return Wrap(
              spacing: 10,
              children: [
                for (final s in Skin.values)
                  SizedBox(width: w, child: _skinCard(s, shop, canBuy ? () => ctl.buy(skinInfo[s]!.product!) : null, price)),
              ],
            );
          },
        ),
        _head(tx('Без рекламы + поддержать автора'), Icons.favorite),
        _card(border: shop.supporter ? C.gold.withValues(alpha: .6) : C.line, [
          Text(
            tx(
              'Ускорение добычи включается сразу, без видео. Покупка поддерживает автора: '
              'сервер, новые эры, сущности и стили.',
            ),
          ),
          const SizedBox(height: 8),
          if (shop.supporter)
            Text(
              tx('Вы поддержали автора — спасибо!'),
              key: const ValueKey('supporter'),
              style: const TextStyle(color: C.gold, fontWeight: FontWeight.w700),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('buy-supporter'),
                onPressed: canBuy ? () => ctl.buy(supporterProduct) : null,
                icon: const Icon(Icons.favorite),
                label: Text(tx('Купить') + price(supporterProduct)),
              ),
            ),
        ]),
        if (shop.billing != null)
          Center(
            child: TextButton(
              key: const ValueKey('restore'),
              onPressed: shop.busy ? null : shop.restore,
              child: Text(tx('Восстановить покупки')),
            ),
          ),
      ],
    );
  }

  Widget _skinCard(Skin s, Shop shop, VoidCallback? buy, String Function(String) price) {
    final info = skinInfo[s]!, owns = shop.owns(s), on = shop.skin == s;
    return _card(border: on ? info.accent.withValues(alpha: .8) : C.line, [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 116, height: 116, child: PlasmaPortrait.spark(cores: 0, skin: s)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx(info.title), style: h2(info.accent)),
                const SizedBox(height: 2),
                Text(tx(info.about), style: const TextStyle(color: C.muted, fontSize: 13)),
                const SizedBox(height: 8),
                if (on)
                  Text(
                    tx('Выбран'),
                    style: const TextStyle(color: C.ok, fontWeight: FontWeight.w700),
                  )
                else
                  FilledButton(
                    key: ValueKey('skin-${s.name}'),
                    onPressed: owns ? () => shop.setSkin(s) : buy,
                    child: Text(owns ? tx('Выбрать') : tx('Купить') + price(info.product!)),
                  ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }
}

/* ---------- развитие проекта ---------- */
class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _head(tx('Поддержать «Искру»'), Icons.favorite_border),
      _card([
        Text(
          key: const ValueKey('support-text'),
          tx(
            '«Искра» — независимый проект одного автора. Реклама в игре только по желанию: видео, за которое '
            'добыча ускоряется на несколько минут. Платные стили меняют лишь вид Искры, а не силу.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tx(
            'Если игра вам нравится и вы хотите, чтобы она росла, поддержать проект можно во вкладке «Магазин». '
            'Это помогает оплачивать сервер учётных записей и рейтингов, '
            'выпускать сборки для разных устройств и находить время на новые эры, технологии, сущности и способности.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tx(
            'Поддержка не даёт игровых преимуществ — это просто спасибо, которое помогает игре жить. '
            'Рассказать об «Искре» друзьям и прислать идеи — тоже большая помощь.',
          ),
          style: const TextStyle(color: C.muted),
        ),
      ]),
      Text(
        tx('Спасибо, что играете!'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: C.gold),
      ),
    ],
  );
}

/* ---------- искра и текущий мир (кнопка «Статистика» в блоке искры) ---------- */
class WorldPanel extends StatelessWidget {
  const WorldPanel(this.g, {super.key});
  final Game g;

  @override
  Widget build(BuildContext context) {
    final s = g.s, x = g.incomeParts(), tr = g.worldTrend();
    double w(String k) => g.stv('w.$k');
    final battles = w('battles'), wins = w('wins');
    final era = s.era == null ? null : Defs.eras[s.era!.i];
    final abil = [
      for (final a in s.abilities)
        if (a != null) '${Defs.abilities[a.id]!.name} ${a.lvl}',
    ];
    return Column(
      key: const ValueKey('world-stats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Искра и мир'), style: h2(C.gold)),
        const SizedBox(height: 4),
        _head(tx('Искра в этом мире'), Icons.auto_awesome),
        _card([
          KV([
            (tx('Добыча искры'), tx('+{n} материи/с', {'n': Fmt.n1(x.base)})),
            (tx('Ядро / скорость искры'), '×${g.coreMul} / ×${Fmt.x(g.sparkSpeed, 2)}'),
            (tx('Бонус прыжка'), '×${Fmt.x(g.bonusMul, 2)}'),
            (tx('Здоровье в бою'), Fmt.n(g.maxHp())),
            (tx('Сила удара'), '≈${Fmt.n(10 * g.med() * g.powMul())}'),
            (tx('ОП / ОС свободно'), '${s.op} / ${s.os}'),
            (tx('Куплено ОП / ОС'), '${s.opB} / ${s.osB}'),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in Defs.params)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(p.color).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(p.color).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${p.name} ${s.char[p.id] ?? 1}${g.eff(p.id).pen > 0 ? ' (−${(g.eff(p.id).pen * 100).round()}%)' : ''}',
                    style: TextStyle(fontSize: 12, color: g.eff(p.id).pen > 0 ? C.bad : C.ink),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tx('Способности: {a}', {'a': abil.isEmpty ? tx('нет') : abil.join(', ')}),
            style: const TextStyle(color: C.muted, fontSize: 13),
          ),
        ]),
        _head(tx('Сражения в этом мире'), Icons.flash_on),
        _card([
          KV([
            (tx('Боёв'), Fmt.n(battles)),
            (tx('Победы / поражения / отступления'), '${Fmt.n(wins)} / ${Fmt.n(w('losses'))} / ${Fmt.n(w('fled'))}'),
            (tx('Доля побед'), battles > 0 ? '${(wins / battles * 100).round()}%' : '—'),
            (tx('Урон нанесён / получен'), '${Fmt.n(w('dmg'))} / ${Fmt.n(w('taken'))}'),
            (tx('Сильнейший удар'), Fmt.n(w('maxHit'))),
            (tx('Применено способностей'), Fmt.n(w('abil'))),
          ]),
        ]),
        _head(tx('Этот мир'), Icons.public),
        _card([
          KV([
            (tx('Время в мире'), Fmt.time(s.worldTime)),
            (tx('Клеток сейчас / рекорд мира'), '${g.own.length} / ${s.worldMax}'),
            (tx('Под угрозой'), '${g.threatCount}'),
            (tx('Захвачено / потеряно'), '${Fmt.n(w('captured'))} / ${Fmt.n(w('lost'))}'),
            (tx('Построено / укреплений'), '${Fmt.n(w('built'))} / ${Fmt.n(w('fort'))}'),
            (tx('Доход'), tx('{n} материи/с', {'n': Fmt.n1(g.income())})),
            (tx('Добыто материи'), Fmt.n(s.we)),
            (tx('Агрессивность'), g.aggrText),
            (tx('Сила тьмы от прыжков'), '×${Fmt.x(g.darkMul, 2)}'),
            if (era != null) (tx('Эра'), tx('«{e}», ещё {t}', {'e': era.name, 't': Fmt.clock(s.era!.left)})),
            (tx('Прыжок сейчас даст'), tx('+{x} к бонусу', {'x': Fmt.x(g.rebirthGain(), 2)})),
          ]),
          const SizedBox(height: 6),
          Text(tr.text.substring(2), style: TextStyle(color: C.kind(tr.kind))),
        ]),
        Text(
          tx('Счётчики боёв, захватов и строек в этом мире ведутся с версии 0.4.2 и обнуляются при прыжке.'),
          style: const TextStyle(color: C.muted, fontSize: 12),
        ),
      ],
    );
  }
}
