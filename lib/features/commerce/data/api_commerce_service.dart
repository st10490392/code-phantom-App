import '../../../core/network/api_client.dart';
import '../domain/commerce_models.dart';

class ApiCommerceService {
  const ApiCommerceService(this._client);

  final ApiClient _client;

  Future<List<CommercePlan>> listPlans() async {
    final response = await _client.get('/public/plans', requiresAuth: false);
    final rows = response['data'] as List? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CommercePlan.fromJson)
        .toList(growable: false);
  }

  Future<List<PaymentMethodOption>> listPaymentMethods() async {
    final response = await _client.get('/public/payment-methods', requiresAuth: false);
    final rows = response['data'] as List? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethodOption.fromJson)
        .toList(growable: false);
  }

  Future<List<CommercePurchase>> listPurchases() async {
    final response = await _client.get('/commerce/purchases');
    final rows = response['data'] as List? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CommercePurchase.fromJson)
        .toList(growable: false);
  }

  Future<List<CommerceSubscription>> listSubscriptions() async {
    final response = await _client.get('/commerce/subscriptions');
    final rows = response['data'] as List? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CommerceSubscription.fromJson)
        .toList(growable: false);
  }

  Future<String> subscriptionManageUrl(String id) async {
    final response = await _client.post('/commerce/subscriptions/$id/manage');
    final data = response['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<CheckoutSession> createCheckout({
    required String planCode,
    required String provider,
  }) async {
    final response = await _client.post(
      '/commerce/checkout',
      body: {'plan_code': planCode, 'provider': provider},
    );
    return CheckoutSession.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<bool> confirmCheckout(CheckoutSession checkout) async {
    if (checkout.provider == 'paypal') {
      await _client.post(
        '/commerce/paypal/capture',
        body: {'order_id': checkout.reference},
      );
      return true;
    }
    if (checkout.provider == 'binance_pay') {
      final response = await _client.post(
        '/commerce/binance-pay/confirm',
        body: {'reference': checkout.reference},
      );
      final data = response['data'] as Map<String, dynamic>;
      return data['paid'] == true;
    }

    // Paystack and Skrill complete from signed server-to-server callbacks.
    return false;
  }
}
