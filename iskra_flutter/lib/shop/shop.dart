// Магазин «Искры»: стили Искры, покупка «Без рекламы + поддержать автора» и ускорение за видео.
// Покупки идут через RuStore (только Android), видео за награду — через Рекламную сеть Яндекса.
// На остальных платформах магазин показывает, что купленное, и где купить остальное.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/skins.dart';

/// Товар «Без рекламы + поддержать автора»: ускорение без видео и знак поддержки
const supporterProduct = 'iskra_supporter';

/// Все товары магазина
final allProducts = [supporterProduct, for (final s in skinInfo.values) ?s.product];

/// Ускорение добычи: во сколько раз и на сколько
const boostMul = 2.0;
const boostTime = Duration(minutes: 10);

sealed class BuyResult {
  const BuyResult();
}

class Bought extends BuyResult {
  const Bought();
}

class BuyCancelled extends BuyResult {
  const BuyCancelled();
}

class BuyFailed extends BuyResult {
  const BuyFailed(this.message);
  final String message;
}

/// Платёжная система магазина приложений
abstract class Billing {
  /// Можно ли покупать на этом устройстве; иначе — причина для игрока
  Future<String?> unavailableReason();

  /// Цены товаров для показа (товар → «149 ₽»)
  Future<Map<String, String>> prices(List<String> ids);

  /// Купленные товары (для восстановления после переустановки)
  Future<Set<String>> owned();

  Future<BuyResult> buy(String id);
}

/// Видео за награду: true — досмотрено, награду выдать
abstract class RewardedAds {
  Future<bool> show();
}

class Shop extends ChangeNotifier {
  Shop(this.prefs, {this.billing, this.ads, this.unlockAll = false}) {
    owned.addAll((prefs.getString(_ownedKey) ?? '').split(',').where((s) => s.isNotEmpty));
    _boostUntil = prefs.getInt(_boostKey) ?? 0;
    final s = Skins.parse(prefs.getString(_skinKey));
    Skins.current = owns(s) ? s : Skin.plasma;
  }

  static const _ownedKey = 'iskra-owned', _skinKey = 'iskra-skin', _boostKey = 'iskra-boost';

  final SharedPreferences prefs;
  final Billing? billing;
  final RewardedAds? ads;

  /// Все стили открыты (сборка для проверки: --dart-define=ISKRA_UNLOCK_ALL=true)
  final bool unlockAll;

  final Set<String> owned = {};
  final Map<String, String> prices = {};

  /// Почему покупки недоступны (null — доступны)
  String? unavailable = 'Покупки доступны в версии для Android из RuStore.';
  bool busy = false;
  int _boostUntil = 0;

  bool get supporter => owned.contains(supporterProduct);
  Skin get skin => Skins.current;
  bool owns(Skin s) => unlockAll || skinInfo[s]!.product == null || owned.contains(skinInfo[s]!.product);

  /// Связаться с магазином: цены и восстановление покупок
  Future<void> init() async {
    final b = billing;
    if (b == null) return;
    try {
      unavailable = await b.unavailableReason();
      if (unavailable == null) {
        prices.addAll(await b.prices(allProducts));
        final got = await b.owned();
        owned
          ..clear()
          ..addAll(got);
        _saveOwned();
        if (!owns(Skins.current)) setSkin(Skin.plasma);
      }
    } catch (e) {
      unavailable = 'Магазин RuStore сейчас недоступен.';
      debugPrint('shop init: $e');
    }
    notifyListeners();
  }

  void setSkin(Skin s) {
    if (!owns(s)) return;
    Skins.current = s;
    prefs.setString(_skinKey, s.name);
    notifyListeners();
  }

  /// Купить товар; возвращает сообщение для ленты (null — покупку отменили)
  Future<(String, String)?> buy(String id) async {
    final b = billing;
    if (b == null || unavailable != null) return (unavailable ?? 'Покупки недоступны.', 'info');
    if (busy) return null;
    busy = true;
    notifyListeners();
    try {
      switch (await b.buy(id)) {
        case Bought():
          owned.add(id);
          _saveOwned();
          return (
            id == supporterProduct ? 'Спасибо за поддержку! Ускорение теперь включается без видео.' : 'Стиль куплен.',
            'good',
          );
        case BuyCancelled():
          return null;
        case BuyFailed(:final message):
          return (message, 'bad');
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Восстановить покупки вручную (кнопка в магазине)
  Future<void> restore() => init();

  void _saveOwned() => prefs.setString(_ownedKey, owned.join(','));

  /* ---------- ускорение добычи ---------- */

  /// Сколько ещё действует ускорение
  Duration get boostLeft {
    final ms = _boostUntil - DateTime.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }

  bool get boosted => boostLeft > Duration.zero;

  /// Ускорение можно взять: за видео или сразу, если автор поддержан
  bool get canBoost => !boosted && !busy && (supporter || ads != null);

  /// Включить ускорение; возвращает сообщение для ленты
  Future<(String, String)> boost() async {
    if (!canBoost) return ('Ускорение уже действует.', 'info');
    if (!supporter) {
      busy = true;
      notifyListeners();
      bool ok;
      try {
        ok = await ads!.show();
      } catch (e) {
        ok = false;
        debugPrint('ads: $e');
      } finally {
        busy = false;
      }
      if (!ok) {
        notifyListeners();
        return ('Видео не досмотрено или пока недоступно — попробуйте позже.', 'info');
      }
    }
    _boostUntil = DateTime.now().add(boostTime).millisecondsSinceEpoch;
    prefs.setInt(_boostKey, _boostUntil);
    notifyListeners();
    return ('Добыча материи ×${boostMul.toInt()} на ${boostTime.inMinutes} минут.', 'good');
  }
}
