import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ideaKey = GlobalKey();
  final _projectsKey = GlobalKey();

  void _scrollTo(GlobalKey key) => Scrollable.ensureVisible(
    key.currentContext!,
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOut,
  );

  void _openSupport() => Navigator.of(context).pushNamed('/support');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SiteHeader(
        items: {
          'Идея': () => _scrollTo(_ideaKey),
          'Проекты': () => _scrollTo(_projectsKey),
          'Поддержать': _openSupport,
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(onSupport: _openSupport),
            _IdeaSection(key: _ideaKey),
            _ProjectsSection(key: _projectsKey),
            Section(child: _SupportCta(onSupport: _openSupport)),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onSupport});
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final style = h1(context);
    return HeroBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('ASB studio · ${Links.site}'),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(
                    text: 'Вселенная',
                    style: TextStyle(
                      foreground: Paint()
                        ..shader =
                            const LinearGradient(
                              colors: [AppColors.accent, AppColors.accent2],
                            ).createShader(
                              Rect.fromLTWH(0, 0, style.fontSize! * 5, 1),
                            ),
                    ),
                  ),
                  const TextSpan(
                    text: ' непрерывно развивающихся, связанных между собой миров',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'ASB studio создаёт не отдельные игры, а вселенную. Каждый мир '
              'самостоятелен, но все они связаны и продолжают развиваться: '
              'события, герои и открытия переходят из мира в мир.',
              style: mutedText(isMobile(context) ? 17 : 19),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              PillButton(
                label: 'Играть в «Искру»',
                primary: true,
                onPressed: () => openUrl(Links.iskra),
              ),
              PillButton(label: 'Поддержать разработку', onPressed: onSupport),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdeaSection extends StatelessWidget {
  const _IdeaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Section(
      alt: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHead(
            eyebrow: 'Идея студии',
            title: 'Миры, которые растут и связаны между собой',
            text:
                'Небольшая команда разработчиков делает не одну большую игру, '
                'а вселенную миров. Миры не замирают после выхода: они непрерывно '
                'развиваются, а тот, кто путешествует по всем, видит общую картину.',
          ),
          ResponsiveGrid(
            children: [
              InfoCard(
                icon: Icons.public,
                title: 'Каждый мир самостоятелен',
                child: Text(
                  'Своя механика, свой жанр и свой финал. Чтобы начать, не нужно '
                  'знать о других играх.',
                  style: mutedText(),
                ),
              ),
              InfoCard(
                icon: Icons.link,
                title: 'Миры связаны',
                child: Text(
                  'Общая история, сквозные персонажи и находки, которые '
                  'откликаются в следующих играх серии.',
                  style: mutedText(),
                ),
              ),
              InfoCard(
                icon: Icons.explore_outlined,
                title: 'Вселенная растёт',
                child: Text(
                  'Каждый новый мир открывает ещё один фрагмент общей карты. '
                  'Игроки видят, как она складывается.',
                  style: mutedText(),
                ),
              ),
              InfoCard(
                icon: Icons.groups_outlined,
                title: 'Вместе с игроками',
                child: Text(
                  'Мы выпускаем рано, слушаем отзывы и развиваем миры вместе с '
                  'теми, кто в них играет.',
                  style: mutedText(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 56),
          const Text('Карта миров', style: h3),
          const SizedBox(height: 18),
          const ResponsiveGrid(
            minItemWidth: 200,
            gap: 16,
            children: [
              _WorldTile(
                number: '01',
                tag: 'Доступен',
                title: 'Искра',
                text: 'Мир шестигранников, тьмы и искры.',
                live: true,
              ),
              _WorldTile(
                number: '02',
                tag: 'В разработке',
                title: 'Скоро',
                text: 'Следующая глава вселенной.',
              ),
              _WorldTile(
                number: '03',
                tag: 'Задумано',
                title: '???',
                text: 'Пока это тайна.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorldTile extends StatelessWidget {
  const _WorldTile({
    required this.number,
    required this.tag,
    required this.title,
    required this.text,
    this.live = false,
  });
  final String number;
  final String tag;
  final String title;
  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: live ? 1 : 0.75,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: live ? AppColors.accent : AppColors.line),
          boxShadow: live
              ? const [
                  BoxShadow(
                    color: Color(0x55FF9A3C),
                    blurRadius: 40,
                    spreadRadius: -10,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'МИР $number',
              style: mutedText(13).copyWith(letterSpacing: 1.3),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: live ? const Color(0x26FF9A3C) : const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: live ? AppColors.accent : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: h3),
            const SizedBox(height: 6),
            Text(text, style: mutedText(14)),
          ],
        ),
      ),
    );
  }
}

/// Цвета «Искры» с iskraplay.ru: блок проекта оформлен в стиле самой игры.
class _IskraColors {
  static const bg = Color(0xFF141026);
  static const panel = Color(0xFF1C1733);
  static const line = Color(0xFF342B55);
  static const ink = Color(0xFFECE6FA);
  static const muted = Color(0xFFA79FC2);
  static const gold = Color(0xFFF2B441);
  static const violet = Color(0xFFA88BE0);
  static const title = Color(0xFFFFF3D6);
}

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final art = Image.asset(
      'assets/images/iskra_cover.jpg',
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      height: wide ? null : 240,
      width: double.infinity,
      semanticLabel: 'Искра среди шестигранников',
    );
    final body = Padding(
      padding: EdgeInsets.all(wide ? 40 : 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'СТРАТЕГИЯ В МИРЕ ШЕСТИГРАННИКОВ',
            style: TextStyle(
              color: _IskraColors.violet,
              letterSpacing: 1.8,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/iskra_icon.png',
                  width: 52,
                  height: 52,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Искра',
                style: TextStyle(
                  fontFamily: 'Philosopher',
                  fontWeight: FontWeight.w700,
                  fontSize: 46,
                  height: 1,
                  color: _IskraColors.title,
                  shadows: [
                    Shadow(color: Color(0xAAF2B441), blurRadius: 28),
                    Shadow(color: Color(0x55F2B441), blurRadius: 60),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Маленькая искра во тьме бесконечного мира. Захватывайте клетки, '
            'сражайтесь с сущностями тьмы, изучайте технологии и совершайте '
            'прыжки в новые области вселенной.',
            style: TextStyle(
              color: _IskraColors.ink,
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in [
                'Мир шестигранников',
                'Бои с сущностями',
                'Технологии и прыжки',
                '24 эры',
              ])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _IskraColors.bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _IskraColors.line),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(
                      color: _IskraColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          const _IskraPlayButton(),
          const SizedBox(height: 12),
          const Text(
            'В браузере, на Android и Windows · прогресс общий для всех устройств',
            style: TextStyle(color: _IskraColors.muted, fontSize: 13),
          ),
        ],
      ),
    );

    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHead(
            eyebrow: 'Реализованные проекты',
            title: 'Наши игры',
            text: 'Первый мир вселенной уже открыт. Остальные появятся здесь по мере выхода.',
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _IskraColors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _IskraColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33F2B441),
                  blurRadius: 60,
                  spreadRadius: -20,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: wide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 380),
                            child: art,
                          ),
                        ),
                        Expanded(flex: 10, child: body),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [art, body],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Золотая кнопка «Играть», как на iskraplay.ru.
class _IskraPlayButton extends StatelessWidget {
  const _IskraPlayButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD47A), _IskraColors.gold, Color(0xFFD9922A)],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: const Color(0xFFFFE2A3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66F2B441),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openUrl(Links.iskra),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, color: Color(0xFF2A1B03)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Играть на iskraplay.ru',
                    style: TextStyle(
                      color: Color(0xFF2A1B03),
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
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
}

class _SupportCta extends StatelessWidget {
  const _SupportCta({required this.onSupport});
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x26FF9A3C), Color(0x2E7C6CFF)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Помогите вселенной расти',
            style: h2(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Мы — независимая команда. Ваша поддержка помогает быстрее '
              'выпускать новые миры.',
              style: mutedText(16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          PillButton(
            label: 'Поддержать разработчика',
            primary: true,
            onPressed: onSupport,
          ),
        ],
      ),
    );
  }
}
