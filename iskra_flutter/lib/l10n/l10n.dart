// Языковые пакеты «Искры»: русский (исходный) и английский.
//
// Ключ перевода — сам русский текст, поэтому русская версия не нуждается в словаре, а непереведённая строка
// показывается по-русски. Подстановки пишутся в ключе как {имя}: tx('Клеток: {n}', {'n': 5}).
// Английские строки лежат в en_*.dart по частям игры и собираются в [_en].
import 'en_core.dart';
import 'en_panels.dart';
import 'en_screens.dart';
import 'en_settings.dart';

enum Lang {
  ru('Русский'),
  en('English');

  const Lang(this.title);
  final String title;

  static Lang parse(String? s) => Lang.values.firstWhere((l) => l.name == s, orElse: () => Lang.ru);
}

/// Текущий язык. Меняется через GameController.setLang, который перерисовывает интерфейс.
Lang lang = Lang.ru;

bool get isEn => lang == Lang.en;

final _en = <String, String>{...enCore, ...enPanels, ...enScreens, ...enSettings};

/// Перевод строки интерфейса на текущий язык
String tx(String ru, [Map<String, Object?> args = const {}]) {
  var s = lang == Lang.en ? (_en[ru] ?? ru) : ru;
  if (args.isNotEmpty) args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Выбор формы по числу: русские три формы (1 клетка, 2 клетки, 5 клеток) или английские две (1 cell, 5 cells)
String plural(num n, String one, String few, String many, {required String en1, required String enMany}) {
  if (lang == Lang.en) return n == 1 ? en1 : enMany;
  final a = n.abs().floor() % 100, b = a % 10;
  if (n != n.floor() || (a >= 11 && a <= 14)) return n != n.floor() ? few : many;
  return b == 1 ? one : (b >= 2 && b <= 4 ? few : many);
}
