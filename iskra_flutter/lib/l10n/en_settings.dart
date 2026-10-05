// Английские строки: settings. Ключ — русский текст, как в коде (см. l10n.dart).
const enSettings = <String, String>{
  // settings.dart: вкладки
  'Настройки': 'Settings',
  'Аккаунт': 'Account',
  'Приложение': 'App',
  'Магазин': 'Shop',
  'Статистика': 'Statistics',
  'Об игре': 'About',
  // settings.dart: приложение
  'Язык': 'Language',
  'Графика и производительность': 'Graphics and Performance',
  'Высокое': 'High',
  'Среднее': 'Medium',
  'Все эффекты, 60 кадров в секунду.': 'All effects, 60 frames per second.',
  '30 кадров, без размытий и сияния в бою. Меньше нагрев и расход батареи.':
      '30 fps, no blur or glow in battle. Less heat and battery drain.',
  'Чёткость изображения в браузере меняется после перезагрузки страницы.':
      'Browser resolution changes after the page is reloaded.',
  'Масштаб интерфейса': 'Interface Scale',
  'Авто (сейчас ×{x})': 'Auto (now ×{x})',
  'Авто увеличивает кнопки, значки и текст на больших экранах и мониторах по размеру окна. '
          'На телефоне масштаб остаётся ×1.':
      'Auto enlarges buttons, icons and text on large screens and monitors to fit the window. '
      'On phones the scale stays ×1.',
  'Звук': 'Sound',
  'Общая громкость': 'Master volume',
  'Музыка': 'Music',
  'Звуки и эффекты': 'Sound effects',
  'Боевая тема во время боя': 'Battle theme during battles',
  'Музыка начнётся после первого касания': 'Music starts after the first tap',
  'Играет: «{t}»': 'Playing: "{t}"',
  'Дальше': 'Next',
  'Мелодии: {list} и боевая «{b}».': 'Tracks: {list} and the battle theme "{b}".',
  'Звёздный дрейф': 'Star Drift',
  'Туманность': 'Nebula',
  'Пульсар': 'Pulsar',
  'Схватка': 'Clash',

  // settings.dart: статистика
  'Этот мир': 'This World',
  'Время в мире': 'Time in world',
  'Клеток сейчас / максимум': 'Cells now / max',
  'Доход': 'Income',
  '{n} материи/с': '{n} matter/s',
  'Побед в этом мире': 'Wins in this world',
  'Агрессивность': 'Aggression',
  'Эра': 'Era',
  '«{e}», ещё {t}': '"{e}", {t} left',
  'Сражения': 'Battles',
  'Боёв начато': 'Battles started',
  'Победы / поражения / отступления': 'Wins / losses / retreats',
  'Доля побед': 'Win rate',
  'Урон нанесён / получен': 'Damage dealt / taken',
  'Сильнейший удар': 'Strongest hit',
  'Применено способностей': 'Abilities used',
  'Побеждено сущностей: {k}, очков рейтинга: {p}': 'Entities defeated: {k}, rating points: {p}',
  'Клеток захвачено / потеряно': 'Cells captured / lost',
  'Построено строений': 'Buildings built',
  'Укреплений': 'Fortifications',
  'Применено артефактов': 'Artifacts used',
  'Артефактов в запасе': 'Artifacts in stock',
  'Рангов технологий': 'Technology ranks',
  'Пульсары': 'Pulsars',
  'За всё время': 'All Time',
  'Прыжков': 'Jumps',
  'Бонус прыжка': 'Jump bonus',
  'Самый долгий мир': 'Longest world',
  'Время в игре': 'Play time',
  'Бои, захваты, урон и время в игре считаются с версии 0.4.0.':
      'Battles, captures, damage and play time are counted since version 0.4.0.',

  // settings.dart: об игре
  'Искра': 'Spark',
  'версия {v}': 'version {v}',
  'Маленькая искра во тьме бесконечного мира шестигранников. Захватывайте клетки, развивайте их, '
          'сражайтесь с сущностями тьмы, собирайте способности и артефакты, изучайте технологии и совершайте прыжки '
          'в новые области вселенной — каждый следующий мир сложнее, но и искра сильнее.':
      'A tiny spark in the darkness of an endless hexagon world. Capture cells and develop them, '
      'fight dark entities, collect abilities and artifacts, research technologies and jump '
      'to new regions of the universe — each new world is harder, but the Spark is stronger too.',
  'История выпусков': 'Release History',
  'Версия {v} — текущая': 'Version {v} — current',
  'Версия {v}': 'Version {v}',

  // settings.dart: магазин
  'Ускорение добычи': 'Income Boost',
  'Добыча материи ×{m} на {t} минут.': 'Matter income ×{m} for {t} minutes.',
  'Действует ещё {t}': 'Active for {t}',
  'Включить': 'Activate',
  'Смотреть видео': 'Watch Video',
  'Видео за ускорение есть в версии для Android.': 'Boost videos are available in the Android version.',
  'Стили Искры': 'Spark Styles',
  'Покупки доступны в версии для Android из RuStore.': 'Purchases are available in the Android version from RuStore.',
  'Магазин RuStore сейчас недоступен.': 'The RuStore shop is unavailable right now.',
  'Для покупок установите RuStore.': 'Install RuStore to make purchases.',
  'Покупки в RuStore сейчас недоступны.': 'RuStore purchases are unavailable right now.',
  'Звёздная плазма': 'Star Plasma',
  'Звезда с короной и протуберанцами. Стиль по умолчанию.': 'A star with a corona and prominences. The default style.',
  'Стимпанк': 'Steampunk',
  'Готика': 'Gothic',
  'Биология': 'Biology',
  'Кристалл': 'Crystal',
  'Ледяной самоцвет: грани ловят свет и рассыпают радугу.': 'An icy gem: its facets catch the light and scatter rainbows.',
  'Выбран': 'Selected',
  'Выбрать': 'Select',
  'Купить': 'Buy',
  'Без рекламы + поддержать автора': 'No Ads + Support the Author',
  'Ускорение добычи включается сразу, без видео. Покупка поддерживает автора: '
          'сервер, новые эры, сущности и стили.':
      'The income boost turns on instantly, no video. The purchase supports the author: '
      'the server, new eras, entities and styles.',
  'Вы поддержали автора — спасибо!': 'You supported the author — thank you!',
  'Восстановить покупки': 'Restore Purchases',

  // settings.dart: развитие проекта
  'Поддержать «Искру»': 'Support Spark',
  '«Искра» — независимый проект одного автора. Реклама в игре только по желанию: видео, за которое '
          'добыча ускоряется на несколько минут. Платные стили меняют лишь вид Искры, а не силу.':
      'Spark is an independent project by a single author. Ads are strictly optional: a video that '
      'boosts your income for a few minutes. Paid styles only change how the Spark looks, not its power.',
  'Если игра вам нравится и вы хотите, чтобы она росла, поддержать проект можно во вкладке «Магазин». '
          'Это помогает оплачивать сервер учётных записей и рейтингов, '
          'выпускать сборки для разных устройств и находить время на новые эры, технологии, сущности и способности.':
      'If you enjoy the game and want it to grow, you can support the project in the Shop tab. '
      'It helps pay for the account and leaderboard server, '
      'ship builds for different devices and find time for new eras, technologies, entities and abilities.',
  'Поддержка не даёт игровых преимуществ — это просто спасибо, которое помогает игре жить. '
          'Рассказать об «Искре» друзьям и прислать идеи — тоже большая помощь.':
      'Support gives no in-game advantage — it is simply a thank-you that keeps the game alive. '
      'Telling friends about Spark and sending ideas helps a lot too.',
  'Спасибо, что играете!': 'Thanks for playing!',

  // settings.dart: искра и мир
  'Искра в этом мире': 'Spark in This World',
  'Добыча искры': 'Spark income',
  '+{n} материи/с': '+{n} matter/s',
  'Ядро / скорость искры': 'Core / Spark speed',
  'Здоровье в бою': 'Battle health',
  'Сила удара': 'Hit strength',
  'ОП / ОС свободно': 'Free PP / AP',
  'Куплено ОП / ОС': 'PP / AP bought',
  'Способности: {a}': 'Abilities: {a}',
  'нет': 'none',
  'Сражения в этом мире': 'Battles in This World',
  'Боёв': 'Battles',
  'Клеток сейчас / рекорд мира': 'Cells now / world record',
  'Под угрозой': 'Under threat',
  'Захвачено / потеряно': 'Captured / lost',
  'Построено / укреплений': 'Built / fortified',
  'Сила тьмы от прыжков': 'Dark strength from jumps',
  'Прыжок сейчас даст': 'Jump now gives',
  '+{x} к бонусу': '+{x} to bonus',
  'Счётчики боёв, захватов и строек в этом мире ведутся с версии 0.4.2 и обнуляются при прыжке.':
      'Battle, capture and build counters in this world are kept since version 0.4.2 and reset on Jump.',
};
