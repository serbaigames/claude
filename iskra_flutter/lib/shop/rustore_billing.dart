// Покупки через RuStore (SDK платежей RuStore Pay). Только Android с установленным RuStore.
// Товары — непотребляемые, заводятся в консоли RuStore с кодами из allProducts (shop.dart).
// ID приложения в консоли RuStore — в android/app/src/main/res/values/rustore.xml.
import 'package:flutter/foundation.dart';
import 'package:flutter_rustore_pay/api/flutter_rustore_pay_client.dart';
import 'package:flutter_rustore_pay/model/preferred_purchase_type.dart';
import 'package:flutter_rustore_pay/model/product_type.dart';
import 'package:flutter_rustore_pay/model/purchase.dart';
import 'package:flutter_rustore_pay/model/purchase_availability.dart';
import 'package:flutter_rustore_pay/model/ru_store_exception.dart';
import 'package:flutter_rustore_pay/model/sdk_theme.dart';

import 'shop.dart';

class RuStoreBilling implements Billing {
  RuStorePayClient get _pay => RuStorePayClient.instance;

  @override
  Future<String?> unavailableReason() async {
    if (!await _pay.ruStoreUtils.isRuStoreInstalled()) return 'Для покупок установите RuStore.';
    return switch (await _pay.purchaseInteractor.getPurchaseAvailability()) {
      Available() => null,
      Unavailable() => 'Покупки в RuStore сейчас недоступны.',
    };
  }

  @override
  Future<Map<String, String>> prices(List<String> ids) async {
    final list = await _pay.productInteractor.getProducts(ids);
    return {for (final p in list) p.productId: p.amountLabel};
  }

  @override
  Future<Set<String>> owned() async {
    final list = await _pay.purchaseInteractor.getPurchases(productType: ProductType.nonConsumable);
    return {
      for (final p in list)
        if (p is ProductPurchase && (p.status == ProductPurchaseStatus.confirmed || p.status == ProductPurchaseStatus.paid))
          p.productId,
    };
  }

  @override
  Future<BuyResult> buy(String id) async {
    try {
      await _pay.purchaseInteractor.purchase(id, preferredPurchaseType: PreferredPurchaseType.oneStep, sdkTheme: SdkTheme.dark);
      return const Bought();
    } on RuStorePurchaseCancelledException {
      return const BuyCancelled();
    } on RuStoreUserUnauthorizedException {
      return const BuyFailed('Войдите в RuStore и повторите покупку.');
    } on RuStoreNotInstalledException {
      return const BuyFailed('Для покупок установите RuStore.');
    } on RuStoreException catch (e) {
      debugPrint('rustore: $e');
      return const BuyFailed('Покупка не прошла. Попробуйте ещё раз позже.');
    }
  }
}
