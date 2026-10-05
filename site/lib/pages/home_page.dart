import 'dart:math';

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
      appBar: SiteHeader(items: {
        'Идея': () => _scrollTo(_ideaKey),
        'Проекты': () => _scrollTo(_projectsKey),
        'Поддержать': _openSupport,
      }),
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
          const Eyebrow('Инди-студия'),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text('Мы строим ', style: style),
              GradientText('вселенную,', style: style),
            ],
          ),
          Text('а не отдельные игры', style: style),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'ASB studio создаёт серию игр-миров, связанных между собой. '
              'Каждая игра самостоятельна, но вместе они складываются в одну '
              'большую историю: события, герои и открытия переходят из мира в мир.',
              style: mutedText(isMobile(context) ? 17 : 19),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(spacing: 12, runSpacing: 12, children: [
            PillButton(
              label: 'Играть в «Искру»',
              primary: true,
              onPressed: () => openUrl(Links.iskra),
            ),
            PillButton(label: 'Поддержать разработку', onPressed: onSupport),
          ]),
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
            title: 'Серия миров, связанных между собой',
            text: 'Небольшая команда разработчиков делает не одну большую игру, '
                'а цепочку миров. Каждый мир можно пройти отдельно, но тот, кто '
                'путешествует по всем, видит общую картину.',
          ),
          ResponsiveGrid(children: [
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
          ]),
          const SizedBox(height: 56),
          const Text('Карта миров', style: h3),
          const SizedBox(height: 18),
          const ResponsiveGrid(minItemWidth: 200, gap: 16, children: [
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
          ]),
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
            Text('МИР $number',
                style: mutedText(13).copyWith(letterSpacing: 1.3)),
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

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final art = SizedBox(
      height: wide ? null : 220,
      child: const CustomPaint(painter: _HexPainter(), child: SizedBox.expand()),
    );
    final body = Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Мир 01'),
          const SizedBox(height: 8),
          Text('Искра', style: h2(context)),
          const SizedBox(height: 14),
          Text(
            'Браузерная игра о мире шестигранников, поглощённом тьмой. '
            'Вы — искра: прыгайте по клеткам, отвоёвывайте мир у тьмы, '
            'развивайте способности и сражайтесь.',
            style: mutedText(16),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in ['Браузер', 'Стратегия', 'Шестигранники'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(c, style: mutedText(13)),
              ),
          ]),
          const SizedBox(height: 24),
          PillButton(
            label: 'Открыть iskraplay.ru',
            primary: true,
            onPressed: () => openUrl(Links.iskra),
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
            text: 'Первый мир серии уже открыт. Остальные появятся здесь по мере выхода.',
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: wide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 320),
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

/// Обложка «Искры»: сетка шестигранников, светящаяся искра в центре.
class _HexPainter extends CustomPainter {
  const _HexPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height * 0.55);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, 0.1),
          radius: 0.9,
          colors: const [Color(0xFF1B1F33), Color(0xFF07080E)],
        ).createShader(rect),
    );

    const r = 26.0;
    final w = sqrt(3) * r;
    final h = 1.5 * r;
    final maxDist = size.shortestSide * 0.7;
    for (var row = -1; row * h < size.height + r; row++) {
      for (var col = -1; col * w < size.width + w; col++) {
        final x = col * w + (row.isOdd ? w / 2 : 0);
        final y = row * h;
        final dist = (Offset(x, y) - center).distance;
        final opacity = max(0.08, 1 - dist / maxDist) * 0.4;
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = pi / 180 * (60 * i - 90);
          final p = Offset(x + r * cos(a), y + r * sin(a));
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFFFB45A).withValues(alpha: opacity),
        );
      }
    }

    final glow = size.shortestSide * 0.35;
    canvas.drawCircle(
      center,
      glow,
      Paint()
        ..shader = RadialGradient(colors: const [
          Color(0xF2FFBE5A),
          Color(0x80FF8C28),
          Color(0x00FF8C28),
        ], stops: const [0.15, 0.4, 1]).createShader(
          Rect.fromCircle(center: center, radius: glow),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          Text('Помогите вселенной расти',
              style: h2(context), textAlign: TextAlign.center),
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
