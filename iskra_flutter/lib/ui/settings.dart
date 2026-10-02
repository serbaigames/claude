// Окно «Настройки»: вкладки сверху (как в рейтингах), под ними разделы выбранной вкладки.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/game.dart';
import '../version.dart';
import 'controller.dart';
import 'gfx.dart';
import 'panels.dart';
import 'sound.dart';
import 'theme.dart';
import 'widgets.dart';

enum SetTab { acc, app, stats, about, dev }

const _setTabs = {
  SetTab.acc: ('Аккаунт', Icons.account_circle_outlined),
  SetTab.app: ('Приложение', Icons.tune),
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
        Text('Настройки', style: h2()),
        const SizedBox(height: 8),
        _bar(),
        const SizedBox(height: 12),
        switch (tab) {
          SetTab.acc => AccountPanel(ctl),
          SetTab.app => AppSettings(ctl),
          SetTab.stats => StatsView(ctl.game),
          SetTab.about => const AboutView(),
          SetTab.dev => const SupportView(),
        },
      ],
    );
  }

  /// Пять вкладок в одну строку: значок и подпись, выбранная подсвечена
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
                          _setTabs[t]!.$1,
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
        _head('Графика и производительность', Icons.speed),
        _card([
          SegmentedButton<GfxLevel>(
            key: const ValueKey('gfx'),
            showSelectedIcon: false,
            segments: [
              for (final l in GfxLevel.values)
                ButtonSegment(
                  value: l,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(gfxNames[l]!)),
                ),
            ],
            selected: {ctl.gfx},
            onSelectionChanged: (v) => ctl.setGfx(v.first),
          ),
          const SizedBox(height: 6),
          Text(gfxInfo[ctl.gfx]!, style: const TextStyle(color: C.muted, fontSize: 13)),
          if (kIsWeb)
            const Text(
              'Чёткость изображения в браузере меняется после перезагрузки страницы.',
              style: TextStyle(color: C.muted, fontSize: 12),
            ),
        ]),
        _head('Масштаб интерфейса', Icons.zoom_out_map),
        _card([
          SegmentedButton<bool>(
            key: const ValueKey('ui-scale'),
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: false, label: Text('×1')),
              ButtonSegment(value: true, label: Text('Авто (сейчас ×${Fmt.x(_autoNow(context), 2)})')),
            ],
            selected: {ctl.uiAuto.value},
            onSelectionChanged: (v) => ctl.setUiAuto(v.first),
          ),
          const SizedBox(height: 6),
          const Text(
            'Авто увеличивает кнопки, значки и текст на больших экранах и мониторах по размеру окна. '
            'На телефоне масштаб остаётся ×1.',
            style: TextStyle(color: C.muted, fontSize: 13),
          ),
        ]),
        _head('Звук', Icons.volume_up_outlined),
        ListenableBuilder(
          listenable: snd,
          builder: (context, _) => _card([
            _slider('vol-master', Icons.volume_up, 'Общая громкость', snd.master, snd.setMaster),
            _slider('vol-music', Icons.music_note, 'Музыка', snd.music, snd.setMusic),
            _slider('vol-sfx', Icons.graphic_eq, 'Звуки и эффекты', snd.effects, snd.setEffects),
            SwitchListTile(
              key: const ValueKey('battle-music'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: snd.battleMusic,
              onChanged: snd.setBattleMusic,
              title: const Text('Боевая тема во время боя'),
            ),
            const Divider(color: C.line, height: 12),
            Row(
              children: [
                const Icon(Icons.album_outlined, size: 18, color: C.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    snd.nowPlaying == null ? 'Музыка начнётся после первого касания' : 'Играет: «${snd.nowPlaying!.name}»',
                    style: const TextStyle(color: C.muted),
                  ),
                ),
                TextButton.icon(
                  onPressed: snd.nowPlaying == null || snd.nowPlaying == battleTrack ? null : snd.nextTrack,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('Дальше'),
                ),
              ],
            ),
            Text(
              'Мелодии: ${ambientTracks.map((t) => '«${t.name}»').join(', ')} и боевая «${battleTrack.name}».',
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
        _head('Этот мир', Icons.public),
        _card([
          KV([
            ('Время в мире', Fmt.time(s.worldTime)),
            ('Клеток сейчас / максимум', '${g.own.length} / ${s.worldMax}'),
            ('Доход', '${Fmt.n1(g.income())} материи/с'),
            ('Добыто материи', Fmt.n(s.we)),
            ('Побед в этом мире', '${s.wk}'),
            ('Агрессивность', g.aggrText),
            if (era != null) ('Эра', '«${era.name}», ещё ${Fmt.clock(s.era!.left)}'),
          ]),
        ]),
        _head('Сражения', Icons.flash_on),
        _card([
          KV([
            ('Боёв начато', Fmt.n(battles)),
            ('Победы / поражения / отступления', '${Fmt.n(wins)} / ${Fmt.n(g.stv('losses'))} / ${Fmt.n(g.stv('fled'))}'),
            ('Доля побед', battles > 0 ? '${(wins / battles * 100).round()}%' : '—'),
            ('Урон нанесён / получен', '${Fmt.n(g.stv('dmg'))} / ${Fmt.n(g.stv('taken'))}'),
            ('Сильнейший удар', Fmt.n(g.stv('maxHit'))),
            ('Применено способностей', Fmt.n(g.stv('abil'))),
          ]),
          const SizedBox(height: 8),
          Text('Побеждено сущностей: $killSum, очков рейтинга: ${Fmt.n(points)}', style: const TextStyle(color: C.muted)),
          const SizedBox(height: 6),
          for (final t in ['low', 'rare', 'epic', 'legend']) _killBar(t, k[t] ?? 0, killSum),
        ]),
        _head('Развитие', Icons.hexagon_outlined),
        _card([
          KV([
            ('Клеток захвачено / потеряно', '${Fmt.n(g.stv('captured'))} / ${Fmt.n(g.stv('lost'))}'),
            ('Построено строений', Fmt.n(g.stv('built'))),
            ('Укреплений', Fmt.n(g.stv('fort'))),
            ('Применено артефактов', Fmt.n(g.stv('arts'))),
            ('Артефактов в запасе', '${s.artifacts.length}'),
            ('Рангов технологий', '$techs'),
            ('Пульсары', '${s.pulsars}'),
          ]),
        ]),
        _head('За всё время', Icons.emoji_events_outlined),
        _card([
          KV([
            ('Материя за всё время', Fmt.n(s.earned)),
            ('Рекорд клеток', '${s.bestCells}'),
            ('Прыжков', '${s.rebirths}'),
            ('Бонус прыжка', '+${Fmt.x(s.bonus * 100, 0)}%'),
            ('Самый долгий мир', Fmt.time(g.stv('longWorld'))),
            ('Время в игре', Fmt.time(g.stv('play'))),
          ]),
        ]),
        const Text('Бои, захваты, урон и время в игре считаются с версии 0.4.0.', style: TextStyle(color: C.muted, fontSize: 12)),
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
            Expanded(child: Text('Искра', style: h2(C.gold))),
            Container(
              key: const ValueKey('app-version'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.goldBg, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'версия $appVersion',
                style: TextStyle(color: C.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Маленькая искра во тьме бесконечного мира шестигранников. Захватывайте клетки, развивайте их, '
          'сражайтесь с сущностями тьмы, собирайте способности и артефакты, изучайте технологии и совершайте прыжки '
          'в новые области вселенной — каждый следующий мир сложнее, но и искра сильнее.',
        ),
      ]),
      _head('История выпусков', Icons.history),
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
                'Версия ${r.version}${i == 0 ? ' — текущая' : ''}',
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

/* ---------- развитие проекта ---------- */
/// Реквизиты для поддержки: (название, значение). Пока пусто — показывается заглушка
const donateDetails = <(String, String)>[];

class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _head('Поддержать «Искру»', Icons.favorite_border),
      _card(const [
        Text(
          '«Искра» — независимый проект одного автора. В игре нет рекламы, нет платных преимуществ и нет покупок, '
          'которые делают одного игрока сильнее другого, и так останется.',
        ),
        SizedBox(height: 8),
        Text(
          'Если игра вам нравится и вы хотите, чтобы она росла, можно поддержать проект и автора добровольным '
          'пожертвованием любого размера. Это помогает оплачивать сервер учётных записей и рейтингов, '
          'выпускать сборки для разных устройств и находить время на новые эры, технологии, сущности и способности.',
        ),
        SizedBox(height: 8),
        Text(
          'Поддержка не даёт игровых преимуществ — это просто спасибо, которое помогает игре жить. '
          'Рассказать об «Искре» друзьям и прислать идеи — тоже большая помощь.',
          style: TextStyle(color: C.muted),
        ),
      ]),
      _head('Реквизиты', Icons.account_balance_wallet_outlined),
      _card([
        if (donateDetails.isEmpty)
          const Text(
            'Реквизиты для поддержки появятся здесь в ближайшем обновлении.',
            key: ValueKey('donate-empty'),
            style: TextStyle(color: C.muted),
          )
        else
          for (final (k, v) in donateDetails)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k, style: const TextStyle(color: C.muted, fontSize: 12)),
                  SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
      ]),
      const Text(
        'Спасибо, что играете!',
        textAlign: TextAlign.center,
        style: TextStyle(color: C.gold),
      ),
    ],
  );
}
