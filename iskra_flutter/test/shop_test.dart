import 'package:flutter_test/flutter_test.dart';
import 'package:iskra/shop/shop.dart';
import 'package:iskra/ui/skins.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBilling implements Billing {
  final bought = <String>{};
  BuyResult next = const Bought();
  @override
  Future<String?> unavailableReason() async => null;
  @override
  Future<Map<String, String>> prices(List<String> ids) async => {for (final i in ids) i: '149 ₽'};
  @override
  Future<Set<String>> owned() async => {...bought};
  @override
  Future<BuyResult> buy(String id) async {
    if (next is Bought) bought.add(id);
    return next;
  }
}

class FakeAds implements RewardedAds {
  bool watched = true;
  int shown = 0;
  @override
  Future<bool> show() async {
    shown++;
    return watched;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('стиль нельзя выбрать, пока он не куплен; покупка открывает и сохраняется', () async {
    final prefs = await SharedPreferences.getInstance();
    final billing = FakeBilling();
    final shop = Shop(prefs, billing: billing);
    await shop.init();
    expect(shop.unavailable, isNull);
    expect(shop.prices['iskra_skin_gothic'], '149 ₽');
    shop.setSkin(Skin.gothic);
    expect(shop.skin, Skin.plasma);
    final r = await shop.buy('iskra_skin_gothic');
    expect(r!.$2, 'good');
    shop.setSkin(Skin.gothic);
    expect(shop.skin, Skin.gothic);
    // после перезапуска: стиль и покупка на месте
    final again = Shop(prefs);
    expect(again.owns(Skin.gothic), isTrue);
    expect(Skins.current, Skin.gothic);
    // магазин не подтвердил покупку (возврат) — стиль сбрасывается
    billing.bought.clear();
    await again.restore();
    expect(again.skin, Skin.gothic, reason: 'без магазина restore ничего не меняет');
    final withStore = Shop(prefs, billing: billing);
    await withStore.init();
    expect(withStore.owns(Skin.gothic), isFalse);
    expect(withStore.skin, Skin.plasma);
  });

  test('отменённая покупка ничего не открывает', () async {
    final prefs = await SharedPreferences.getInstance();
    final billing = FakeBilling()..next = const BuyCancelled();
    final shop = Shop(prefs, billing: billing);
    await shop.init();
    expect(await shop.buy(supporterProduct), isNull);
    expect(shop.supporter, isFalse);
  });

  test('без магазина покупки недоступны', () async {
    final shop = Shop(await SharedPreferences.getInstance());
    await shop.init();
    expect(shop.unavailable, isNotNull);
    expect((await shop.buy(supporterProduct))!.$2, 'info');
    expect(shop.canBoost, isFalse);
  });

  test('ускорение: за видео, а у поддержавших — без видео', () async {
    final prefs = await SharedPreferences.getInstance();
    final ads = FakeAds()..watched = false;
    final shop = Shop(prefs, billing: FakeBilling(), ads: ads);
    await shop.init();
    expect(shop.canBoost, isTrue);
    await shop.boost();
    expect(shop.boosted, isFalse, reason: 'видео не досмотрено');
    ads.watched = true;
    await shop.boost();
    expect(shop.boosted, isTrue);
    expect(shop.boostLeft.inMinutes, boostTime.inMinutes - 1);
    expect(shop.canBoost, isFalse);
    expect(ads.shown, 2);

    SharedPreferences.setMockInitialValues({});
    final p2 = await SharedPreferences.getInstance();
    final s2 = Shop(p2, billing: FakeBilling(), ads: ads);
    await s2.init();
    await s2.buy(supporterProduct);
    await s2.boost();
    expect(s2.boosted, isTrue);
    expect(ads.shown, 2, reason: 'поддержавшим видео не показывается');
  });
}
