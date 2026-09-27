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
