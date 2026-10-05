import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme.dart';

Future<void> openUrl(String url) =>
    launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');

bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < 720;

/// Ограничивает ширину контента и добавляет боковые отступы.
class Content extends StatelessWidget {
  const Content({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

class Section extends StatelessWidget {
  const Section({super.key, required this.child, this.alt = false});
  final Widget child;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: alt
          ? const BoxDecoration(
              color: AppColors.bg2,
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.line),
              ),
            )
          : null,
      padding: EdgeInsets.symmetric(vertical: isMobile(context) ? 56 : 80),
      child: Content(child: child),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        fontSize: 13,
      ),
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead({super.key, this.eyebrow, required this.title, this.text});
  final String? eyebrow;
  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[Eyebrow(eyebrow!), const SizedBox(height: 10)],
          Text(title, style: h2(context)),
          if (text != null) ...[
            const SizedBox(height: 14),
            Text(text!, style: mutedText(16)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

TextStyle h1(BuildContext context) => TextStyle(
      fontSize: isMobile(context) ? 38 : 60,
      height: 1.1,
      fontWeight: FontWeight.w800,
    );

TextStyle h2(BuildContext context) => TextStyle(
      fontSize: isMobile(context) ? 28 : 38,
      height: 1.15,
      fontWeight: FontWeight.w800,
    );

const h3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3);

TextStyle mutedText([double size = 15]) =>
    TextStyle(color: AppColors.muted, fontSize: size, height: 1.6);

/// Текст с градиентной заливкой.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        colors: [AppColors.accent, AppColors.accent2],
      ).createShader(rect),
      child: Text(text, style: style),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 30),
          const SizedBox(height: 14),
          Text(title, style: h3),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Сетка карточек одинаковой ширины, число колонок зависит от ширины экрана.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.gap = 20,
  });
  final List<Widget> children;
  final double minItemWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = ((c.maxWidth + gap) / (minItemWidth + gap))
          .floor()
          .clamp(1, children.length);
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        final rowItems = children.sublist(i, (i + cols).clamp(0, children.length));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(
                  child: j < rowItems.length ? rowItems[j] : const SizedBox(),
                ),
              ],
            ],
          ),
        ));
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            rows[i],
          ],
        ],
      );
    });
  }
}

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
    const padding = EdgeInsets.symmetric(horizontal: 22, vertical: 18);
    const textStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 15);
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF1A1006),
          shape: shape,
          padding: padding,
          textStyle: textStyle,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        shape: shape,
        padding: padding,
        textStyle: textStyle,
      ),
      child: Text(label),
    );
  }
}

/// Шапка с логотипом и навигацией. На узком экране пункты уходят в меню.
class SiteHeader extends StatelessWidget implements PreferredSizeWidget {
  const SiteHeader({super.key, required this.items});
  final Map<String, VoidCallback> items;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xF00B0D14),
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Content(
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (_) => false),
              child: const Row(children: [Logo(), SizedBox(width: 10), Text(
                'ASB studio',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.6),
              )]),
            ),
            const Spacer(),
            if (mobile)
              PopupMenuButton<VoidCallback>(
                tooltip: 'Меню',
                icon: const Icon(Icons.menu),
                color: AppColors.bg2,
                onSelected: (cb) => cb(),
                itemBuilder: (_) => [
                  for (final e in items.entries)
                    PopupMenuItem(value: e.value, child: Text(e.key)),
                ],
              )
            else
              for (final e in items.entries)
                TextButton(
                  onPressed: e.value,
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  child: Text(e.key, style: const TextStyle(fontSize: 15)),
                ),
          ],
        ),
      ),
    );
  }
}

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const SweepGradient(
          colors: [AppColors.accent, AppColors.accent2, AppColors.accent],
        ),
      ),
      child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.bg),
    );
  }
}

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final style = mutedText(14);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Content(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('© ${DateTime.now().year} ASB studio', style: style),
            InkWell(
              onTap: () => openUrl(Links.iskra),
              child: Text('iskraplay.ru', style: style),
            ),
          ],
        ),
      ),
    );
  }
}

/// Мягкие цветные пятна на фоне первого экрана.
class HeroBackground extends StatelessWidget {
  const HeroBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.9, -0.8),
          radius: 1.0,
          colors: [Color(0x407C6CFF), Color(0x000B0D14)],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-1.0, 1.0),
            radius: 0.9,
            colors: [Color(0x2EFF9A3C), Color(0x000B0D14)],
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: isMobile(context) ? 64 : 110),
        child: Content(child: child),
      ),
    );
  }
}
