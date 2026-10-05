import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    void home() =>
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    return Scaffold(
      appBar: SiteHeader(items: {'Главная': home, 'Поддержать': () {}}),
      body: SingleChildScrollView(
        child: Column(
          children: [
            HeroBackground(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Поддержка'),
                  const SizedBox(height: 14),
                  Wrap(children: [
                    Text('Поддержите ', style: h1(context)),
                    GradientText('разработчика', style: h1(context)),
                  ]),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Text(
                      'Мы делаем игры без издателя и инвесторов. Каждый донат '
                      'идёт на разработку новых миров: графику, музыку, серверы '
                      'и время команды. Спасибо, что вы с нами!',
                      style: mutedText(isMobile(context) ? 17 : 19),
                    ),
                  ),
                ],
              ),
            ),
            Section(
              alt: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHead(
                    title: 'Как помочь',
                    text: 'Выберите удобный способ. Любая сумма важна.',
                  ),
                  ResponsiveGrid(minItemWidth: 260, children: [
                    const _DonateCard(),
                    InfoCard(
                      icon: Icons.star_outline,
                      title: 'Ежемесячная подписка',
                      child: _CardBody(
                        text: 'Регулярная поддержка на Boosty: ранний доступ к '
                            'новым мирам, дневники разработки и закрытые тесты.',
                        action: PillButton(
                          label: 'Стать спонсором',
                          onPressed: () => openUrl(SupportConfig.subscribeUrl),
                        ),
                      ),
                    ),
                    const InfoCard(
                      icon: Icons.account_balance_outlined,
                      title: 'Перевод по реквизитам',
                      child: _CardBody(
                        text: 'Перевод по номеру карты или через СБП.',
                        action: _CopyRow(value: SupportConfig.cardNumber),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHead(title: 'Помочь можно и без денег'),
                  ResponsiveGrid(children: [
                    InfoCard(
                      icon: Icons.sports_esports_outlined,
                      title: 'Играйте',
                      child: Text(
                        'Заходите в «Искру» на iskraplay.ru и проходите миры. '
                        'Это лучшая мотивация.',
                        style: mutedText(),
                      ),
                    ),
                    InfoCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'Делитесь отзывами',
                      child: Text(
                        'Расскажите, что понравилось и что улучшить. Мы читаем '
                        'каждый отзыв.',
                        style: mutedText(),
                      ),
                    ),
                    InfoCard(
                      icon: Icons.campaign_outlined,
                      title: 'Расскажите друзьям',
                      child: Text(
                        'Поделитесь ссылкой на игру или на этот сайт. Чем больше '
                        'игроков, тем быстрее растёт вселенная.',
                        style: mutedText(),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

/// Текст карточки и кнопка, прижатая к низу.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.text, required this.action});
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: mutedText()),
        const SizedBox(height: 20),
        action,
      ],
    );
  }
}

class _DonateCard extends StatefulWidget {
  const _DonateCard();

  @override
  State<_DonateCard> createState() => _DonateCardState();
}

class _DonateCardState extends State<_DonateCard> {
  int _amount = SupportConfig.donateAmounts[1];

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      icon: Icons.credit_card,
      title: 'Разовый донат',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Быстрый перевод картой через сервис донатов.',
              style: mutedText()),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in SupportConfig.donateAmounts)
              OutlinedButton(
                onPressed: () => setState(() => _amount = a),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      a == _amount ? AppColors.accent : AppColors.text,
                  side: BorderSide(
                    color: a == _amount ? AppColors.accent : AppColors.line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('$a ₽'),
              ),
          ]),
          const SizedBox(height: 20),
          PillButton(
            label: 'Поддержать на $_amount ₽',
            primary: true,
            onPressed: () => openUrl(
              SupportConfig.donateUrl.replaceAll('{amount}', '$_amount'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        OutlinedButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Номер скопирован')),
              );
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.muted,
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Копировать'),
        ),
      ],
    );
  }
}
