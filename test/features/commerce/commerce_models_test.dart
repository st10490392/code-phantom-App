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

  test('purchase and subscription history parse backend billing records', () {
    final purchase = CommercePurchase.fromJson({
      'id': 'p1',
      'plan_code': 'scanner_forex',
      'provider': 'paypal',
      'status': 'PAID',
      'amount_minor': '19900',
      'currency': 'ZAR',
      'created_at': '2026-09-27T09:00:00.000Z',
      'paid_at': '2026-09-27T09:01:00.000Z',
    });
    final subscription = CommerceSubscription.fromJson({
      'id': 's1',
      'plan_code': 'signals_monthly',
      'provider': 'paystack',
      'status': 'ACTIVE',
      'amount_minor': 9900,
      'currency': 'ZAR',
      'current_period_end': '2026-10-27T09:00:00.000Z',
      'next_payment_at': '2026-10-27T09:00:00.000Z',
    });

    expect(purchase.status, 'PAID');
    expect(purchase.amountMinor, 19900);
    expect(subscription.status, 'ACTIVE');
    expect(subscription.nextPaymentAt, isNotNull);
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
