class CommercePlan {
  const CommercePlan({
    required this.code,
    required this.name,
    required this.billingType,
    required this.billingInterval,
    required this.priceAmountMinor,
    required this.priceCurrency,
  });

  final String code;
  final String name;
  final String billingType;
  final String? billingInterval;
  final int? priceAmountMinor;
  final String? priceCurrency;

  bool get isSubscription => billingType == 'SUBSCRIPTION';

  factory CommercePlan.fromJson(Map<String, dynamic> json) => CommercePlan(
        code: json['code'] as String,
        name: json['name'] as String,
        billingType: json['billing_type'] as String? ?? 'CUSTOM',
        billingInterval: json['billing_interval'] as String?,
        priceAmountMinor: switch (json['price_amount_minor']) {
          int value => value,
          String value => int.tryParse(value),
          _ => null,
        },
        priceCurrency: json['price_currency'] as String?,
      );
}

class PaymentMethodOption {
  const PaymentMethodOption({
    required this.code,
    required this.name,
    required this.description,
    required this.recurring,
    required this.kind,
  });

  final String code;
  final String name;
  final String description;
  final bool recurring;
  final String kind;

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) => PaymentMethodOption(
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        recurring: json['recurring'] as bool? ?? false,
        kind: json['kind'] as String? ?? 'wallet',
      );
}

class CheckoutSession {
  const CheckoutSession({
    required this.provider,
    required this.reference,
    required this.authorizationUrl,
  });

  final String provider;
  final String reference;
  final String authorizationUrl;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) => CheckoutSession(
        provider: json['provider'] as String,
        reference: json['reference'] as String,
        authorizationUrl: json['authorization_url'] as String,
      );
}


class CommercePurchase {
  const CommercePurchase({
    required this.id,
    required this.planCode,
    required this.provider,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.createdAt,
    required this.paidAt,
  });

  final String id;
  final String planCode;
  final String provider;
  final String status;
  final int? amountMinor;
  final String? currency;
  final DateTime createdAt;
  final DateTime? paidAt;

  factory CommercePurchase.fromJson(Map<String, dynamic> json) => CommercePurchase(
        id: json['id'] as String,
        planCode: json['plan_code'] as String,
        provider: json['provider'] as String,
        status: json['status'] as String,
        amountMinor: switch (json['amount_minor']) {
          int value => value,
          String value => int.tryParse(value),
          _ => null,
        },
        currency: json['currency'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        paidAt: json['paid_at'] is String
            ? DateTime.tryParse(json['paid_at'] as String)
            : null,
      );
}

class CommerceSubscription {
  const CommerceSubscription({
    required this.id,
    required this.planCode,
    required this.provider,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.currentPeriodEnd,
    required this.nextPaymentAt,
  });

  final String id;
  final String planCode;
  final String provider;
  final String status;
  final int? amountMinor;
  final String? currency;
  final DateTime? currentPeriodEnd;
  final DateTime? nextPaymentAt;

  factory CommerceSubscription.fromJson(Map<String, dynamic> json) =>
      CommerceSubscription(
        id: json['id'] as String,
        planCode: json['plan_code'] as String,
        provider: json['provider'] as String,
        status: json['status'] as String,
        amountMinor: switch (json['amount_minor']) {
          int value => value,
          String value => int.tryParse(value),
          _ => null,
        },
        currency: json['currency'] as String?,
        currentPeriodEnd: json['current_period_end'] is String
            ? DateTime.tryParse(json['current_period_end'] as String)
            : null,
        nextPaymentAt: json['next_payment_at'] is String
            ? DateTime.tryParse(json['next_payment_at'] as String)
            : null,
      );
}
