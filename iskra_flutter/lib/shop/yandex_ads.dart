// Видео за награду из Рекламной сети Яндекса (Android).
// Блок рекламы «Искры» — R-M-20184590-1, в выпускной сборке он по умолчанию;
// другой можно задать при сборке: --dart-define=ISKRA_AD_UNIT=R-M-XXXXXXX-Y.
// В отладочной сборке — демонстрационный блок Яндекса (тестовое видео), чтобы не крутить настоящую рекламу.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'shop.dart';

const _adUnit = String.fromEnvironment('ISKRA_AD_UNIT');
const adUnitId = _adUnit != '' ? _adUnit : (kReleaseMode ? 'R-M-20184590-1' : 'demo-rewarded-yandex');

class YandexRewardedAds implements RewardedAds {
  YandexRewardedAds() {
    _init = YandexAds.initialize().then((_) => _preload());
  }

  late final Future<void> _init;
  final _loader = RewardedAdLoader();
  Future<RewardedAd?>? _next;

  /// Видео загружается заранее, чтобы по кнопке показаться сразу
  void _preload() {
    _next = _loader.loadAd(adRequest: const AdRequest(adUnitId: adUnitId)).then<RewardedAd?>((ad) => ad).catchError((Object e) {
      debugPrint('ads load: $e');
      return null;
    });
  }

  @override
  Future<bool> show() async {
    await _init;
    var ad = await _next;
    if (ad == null) {
      // прошлая загрузка не удалась — пробуем ещё раз прямо сейчас
      _preload();
      ad = await _next;
    }
    _next = null;
    if (ad == null) return false;
    try {
      var rewarded = false;
      await ad.setAdEventListener(eventListener: RewardedAdEventListener(onRewarded: (_) => rewarded = true));
      await ad.show();
      final reward = await ad.waitForDismiss();
      return rewarded || reward != null;
    } finally {
      ad.destroy();
      _preload();
    }
  }
}
