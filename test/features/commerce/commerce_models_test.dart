import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/commerce/domain/commerce_models.dart';

void main() {
  test('CommercePlan parses backend catalog prices', () {
    final plan = CommercePlan.fromJson({
      'code': 'scanner_forex',
      'name': 'CPT Scanner Forex',
      'billing_type': 'SUBSCRIPTION',
      'billing_interval': 'MONTH',
      'price_amount_minor': '19900',
      'price_currency': 'ZAR',
    });

    expect(plan.code, 'scanner_forex');
    expect(plan.priceAmountMinor, 19900);
    expect(plan.priceCurrency, 'ZAR');
    expect(plan.isSubscription, isTrue);
  });

  test('PaymentMethodOption keeps recurring capability server-controlled', () {
    final method = PaymentMethodOption.fromJson({
      'code': 'paypal',
      'name': 'PayPal',
      'description': 'Pay securely with PayPal.',
      'recurring': false,
      'kind': 'wallet',
    });

    expect(method.code, 'paypal');
    expect(method.recurring, isFalse);
    expect(method.kind, 'wallet');
  });

  test('CheckoutSession accepts only the backend checkout fields used by the app', () {
    final checkout = CheckoutSession.fromJson({
      'provider': 'binance_pay',
      'reference': 'CPT12345678901234567890123456789',
      'authorization_url': 'https://example.test/checkout',
    });

    expect(checkout.provider, 'binance_pay');
    expect(checkout.reference, startsWith('CPT'));
    expect(checkout.authorizationUrl, startsWith('https://'));
  });
}
