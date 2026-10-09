// Английские строки: screens. Ключ — русский текст, как в коде (см. l10n.dart).
const enScreens = <String, String>{
  // main.dart, home_screen.dart
  'Искра': 'Spark',
  'Вы играете без учётной записи': "You're playing without an account",
  'Прогресс хранится только на этом устройстве. Войдите или зарегистрируйтесь, чтобы сохранять его на сервере, '
          'продолжать игру на другом устройстве и попасть в рейтинги.':
      'Progress is stored only on this device. Sign in or register to save it on the server, '
      'continue on another device and get on the leaderboards.',
  'Войти или зарегистрироваться': 'Sign in or register',
  'Играть без входа': 'Play without signing in',
  'Материя': 'Matter',
  'Добыча ×{x}': 'Income ×{x}',
  'Добыча': 'Income',
  'пауза': 'paused',
  '+{v}/с': '+{v}/s',
  'Добыча ускорена — подробности в окне Искры': 'Income boosted — details in the Spark window',
  'Суммарная добыча материи в секунду': 'Total matter income per second',
  'Заводы': 'Factories',
  'Бонус заводов ко всей добыче: сумма процентов всех заводов ÷ число клеток':
      'Factory bonus to all income: sum of all factory percents ÷ number of cells',
  'Клетки': 'Cells',
  'Всего клеток (из них под угрозой)': 'Total cells (threatened)',
  'Бонус': 'Bonus',
  'Пульсары': 'Pulsars',
  'Пульсары — валюта технологий': 'Pulsars are the currency of technologies',
  'Эры': 'Eras',
  '+{x} к бонусу': '+{x} to bonus',
  'Прыжок искры': 'Spark Jump',
  'Прыжок: нужна технология': 'Jump: technology required',
  'Продолжить': 'Resume',
  'Пауза': 'Pause',
  'Скорость ×{s}': 'Speed ×{s}',
  'искру': 'the Spark',
  'свою клетку': 'your cell',
  'клетку тьмы': 'a dark cell',
  'Выберите на карте {what} — артефакт применится к ней.': 'Select {what} on the map to apply the artifact.',
  'Отмена': 'Cancel',
  '+{v} материи/с · ядро ×{c}': '+{v} matter/s · core ×{c}',
  'бонус прыжка ×{x} · искру нельзя потерять': "jump bonus ×{x} · the Spark can't be lost",
  'Статистика': 'Statistics',
  'Ваша клетка · ур. {lv}': 'Your cell · lv. {lv}',
  'угроза': 'threatened',
  'защищена': 'protected',
  ' · сосед {n}': ' · neighbor {n}',
  'материя {m}% · энергия {e}% · сила {f}% · строения {u} из {c}':
      'matter {m}% · energy {e}% · force {f}% · buildings {u} of {c}',
  'Укрепить': 'Fortify',
  'Развитие': 'Develop',
  'Свободная клетка': 'Free cell',
  'нужно ещё {n} материи': 'need {n} more matter',
  'защитник побеждён, можно взять': 'defender defeated, ready to capture',
  'Захватить': 'Capture',
  'Клетка': 'Cell',
  'мощь {m} · {fc}': 'might {m} · {fc}',
  'Атаковать': 'Attack',
  'Параметры\nискры': 'Spark\nstats',
  'Закрыть': 'Close',

  // overlays.dart
  'Покров: урон по вам −50%': 'Veil: damage to you −50%',
  'Неуязвимость': 'Invulnerable',
  'Ускорение ходов': 'Faster turns',
  'Восстановление здоровья': 'Health regeneration',
  'Зеркало: удары отражаются': 'Mirror: hits are reflected',
  'Враг ослаблен': 'Enemy weakened',
  'Враг горит': 'Enemy is burning',
  'Особенности врага отключены': 'Enemy traits disabled',
  'Щит врага: урон по нему не проходит': 'Enemy shield: no damage gets through',
  'Сущность': 'Entity',
  'Враг': 'Enemy',
  'Свободная материя: {n}': 'Free matter: {n}',
  'Начать бой': 'Start Battle',
  'Отступить': 'Retreat',
  '−{n} материи и клетка': '−{n} matter and the cell',
  '−{n} материи': '−{n} matter',
  'без штрафа': 'no penalty',
  'пусто': 'empty',
  '{name}: {desc}; откат {cd} с': '{name}: {desc}; cooldown {cd} s',
  '{n} мат.': '{n} mat.',
  '«{name}» уже есть. Можно повысить её уровень бесплатно или взять очки способностей.':
      'You already have “{name}”. Upgrade it for free or take ability points.',
  'Повысить до ур. {n}': 'Upgrade to lv. {n}',
  'Взять очки способностей': 'Take Ability Points',
  '+{n} ОС': '+{n} AP',
  '{name} — {desc}. Все ячейки заняты: выберите, какую способность заменить.':
      '{name} — {desc}. All slots are taken: choose an ability to replace.',
  'Заменить «{name}», ур. {n}': 'Replace “{name}”, lv. {n}',
  'вернётся {n} ОС': 'refunds {n} AP',
  'Не брать': 'Skip',
  'Скрыть журнал боя': 'Hide battle log',
  'Журнал боя': 'Battle log',
  'Клетка под ударом!': 'Cell under attack!',
  '{foe} ({tier}) мощью {m} прорывает защиту вашей клетки ({d}). Игра на паузе.':
      'A {foe} ({tier}) with might {m} is breaking through your cell’s defense ({d}). The game is paused.',
  'Защитите клетку в бою — при победе сущность будет побеждена. Если отступить или проиграть, клетка перейдёт к тьме.':
      'Defend the cell in battle — win and the entity is defeated. Retreat or lose, and the cell goes to the Dark.',
  'Бежать': 'Flee',
  'Защитить': 'Defend',
  'Искра угасает — прыжок неизбежен': 'The Spark is fading — a Jump is inevitable',
  'Тьма поглотила этот мир': 'The Dark has consumed this world',
  'Из {max} клеток осталось {n}: здесь рост уже не вернуть. '
          'Прыжок даст +{gain} к бонусу и новый мир, где искра станет сильнее.':
      'Only {n} of {max} cells are left: there is no growing back here. '
      'A Jump gives +{gain} to bonus and a new world where the Spark grows stronger.',
  'Материя ушла в минус: в этой области вселенной искре больше не на что опереться.':
      'Matter went negative: the Spark has nothing left to rely on in this region of the universe.',
  'Искра прыгает в новую область вселенной, сжигая все накопленные ресурсы на своё развитие. '
          'Рост начнётся сначала, но уже с бонусами от текущего воплощения.':
      'The Spark jumps to a new region of the universe, burning all gathered resources to grow stronger. '
      'Growth starts over, but with bonuses from the current incarnation.',
  'Итоги этого мира': 'This world’s results',
  'Время в мире': 'Time in world',
  'Рекорд клеток': 'Most cells',
  'Клеток сейчас': 'Cells now',
  'Побеждено сущностей': 'Entities defeated',
  'Добыто материи': 'Matter gathered',
  'Агрессивность': 'Aggression',
  'Что даст прыжок': 'What the Jump gives',
  'Бонус искры': 'Spark bonus',
  'Добыча от бонуса': 'Income from bonus',
  'Сила в бою от бонуса': 'Battle strength from bonus',
  'Сила тьмы': 'Dark strength',
  'Скорость искры': 'Spark speed',
  'Новая область': 'New region',
  'Сгорит: клетки, материя, параметры персонажа, ОП, ОС и навыки (кроме Искрового удара). '
          'Останется: бонус искры, ядра, артефакты, изученные технологии и пульсары, рекорды и учётная запись.':
      'Lost: cells, matter, character parameters, PP, AP and skills (except Spark Strike). '
      'Kept: Spark bonus, cores, artifacts, researched technologies and pulsars, records and your account.',
  'Остаться': 'Stay',
  'Прыгнуть': 'Jump',
  'Какой прогресс оставить?': 'Which progress to keep?',
  'В учётной записи уже есть сохранение, и на этом устройстве тоже есть прогресс. Выберите, какое продолжить — второе будет заменено.': 'Your account already has a save, and this device has progress too. Choose which one to continue — the other will be replaced.',
  'На сервере есть сохранение с другого устройства, которое новее, чем здесь. Выберите, какое продолжить — второе будет заменено.':
      'The server has a newer save from another device. Choose which one to continue — the other will be replaced.',
  'С сервера': 'From Server',
  'сохранено {when}': 'saved {when}',
  'С этого устройства': 'From This Device',
  'Искра во тьме': 'A Spark in the Dark',
  'Вы — искра в мире шестигранников. Видно только одну клетку вокруг ваших владений, дальше — тьма.':
      'You are a spark in a world of hexagons. You can see only one cell around your domain; beyond it lies the Dark.',
  'Нажмите на фиолетовую клетку рядом с искрой и атакуйте живущую в ней сущность. '
          'После победы клетку можно захватить за материю, равную её мощи.':
      'Tap a purple cell next to the Spark and attack the entity living in it. '
      'After a win, you can capture the cell for matter equal to its might.',
  'Клетки тьмы растут. Если мощь соседа станет выше защиты вашей клетки, тьма заберёт её вместе со строениями. '
          'Искру потерять нельзя.':
      'Dark cells grow. If a neighbor’s might exceeds your cell’s defense, the Dark takes it along with its buildings. '
      'The Spark itself can’t be lost.',
  'Стройте шахты и заводы, укрепляйте защиту, прокачивайте персонажа и собирайте способности. '
          'Когда станет тесно — совершите прыжок искры и получите бонус.':
      'Build mines and factories, strengthen defense, level up your character and collect abilities. '
      'When things get tight, make a Spark Jump and get a bonus.',
  'Начать': 'Start',
  'Эра на стороне искры': 'An era on the Spark’s side',
  'Эра на стороне тьмы': 'An era on the Dark’s side',
  'Смешанная эра': 'A mixed era',
  'Новая эра': 'New era',
  'Длительность': 'Duration',
  'Осталось': 'Remaining',
  'Понятно': 'Got it',

  // hex_map.dart
  'свободна · {m}': 'free · {m}',
  'рост ×2': 'growth ×2',
  'ур. {n}': 'lv. {n}',
  '{d} · ур. {n}': '{d} · lv. {n}',

  // controller.dart
  'Сохранение с сервера повреждено.': 'The server save is corrupted.',
  'Загружен прогресс с сервера.': 'Progress loaded from the server.',
  'Прыжок закрыт: изучите технологию «Прыжок» во вкладке «Технологии».':
      'Jump is locked: research the “Jump” technology in the Technologies tab.',

  // portraits.dart, map_art.dart
  'свободно': 'free',
  'шахта': 'mine',
  'завод': 'factory',
  'башня': 'tower',
};
