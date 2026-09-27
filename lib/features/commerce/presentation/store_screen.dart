import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/commerce_models.dart';
import 'commerce_providers.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  CheckoutSession? _pending;
  String? _message;
  bool _busy = false;

  String _price(CommercePlan plan) {
    final amount = plan.priceAmountMinor;
    final currency = plan.priceCurrency;
    if (amount == null || currency == null) return 'Price not published';
    try {
      return NumberFormat.simpleCurrency(name: currency).format(amount / 100);
    } catch (_) {
      return currency + ' ' + (amount / 100).toStringAsFixed(2);
    }
  }

  String _billing(CommercePlan plan) {
    if (plan.billingType == 'LIFETIME') return 'Lifetime';
    return switch (plan.billingInterval) {
      'MONTH' => 'per month',
      'QUARTER' => 'per quarter',
      'YEAR' => 'per year',
      _ => plan.billingType.toLowerCase(),
    };
  }

  Future<void> _checkout(
    CommercePlan plan,
    PaymentMethodOption method,
  ) async {
    final service = ref.read(commerceServiceProvider);
    if (service == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final checkout = await service.createCheckout(
        planCode: plan.code,
        provider: method.code,
      );
      final uri = Uri.tryParse(checkout.authorizationUrl);
      if (uri == null || uri.scheme != 'https') {
        throw Exception('The payment provider returned an invalid checkout link.');
      }

      _pending = checkout;
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open secure checkout.');

      if (mounted) {
        setState(() {
          if (method.code == 'paypal' || method.code == 'binance_pay') {
            _message =
                'Complete payment in the browser, return here, then tap Confirm payment.';
          } else {
            _message =
                'Complete payment in the browser. Access will unlock after the provider confirms it.';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPending() async {
    final checkout = _pending;
    final service = ref.read(commerceServiceProvider);
    if (checkout == null || service == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final confirmed = await service.confirmCheckout(checkout);
      await ref.read(authControllerProvider.notifier).refreshAccount();
      ref.invalidate(commercePlansProvider);
      ref.invalidate(paymentMethodsProvider);

      if (mounted) {
        setState(() {
          if (confirmed) _pending = null;
          _message = confirmed
              ? 'Payment confirmed. Your CodePhantom services have been refreshed.'
              : 'The provider has not confirmed payment yet. Try again shortly.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(commercePlansProvider);
    ref.invalidate(paymentMethodsProvider);
    await ref.read(authControllerProvider.notifier).refreshAccount();
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(commercePlansProvider);
    final methods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Services & Billing',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Purchase access through secure provider-hosted checkout. '
                'CodePhantom never handles your card, PayPal, Skrill or Binance credentials.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PhantomCard(
                  child: Text(
                    _message!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              if (_pending != null &&
                  (_pending!.provider == 'paypal' ||
                      _pending!.provider == 'binance_pay')) ...[
                const SizedBox(height: AppSpacing.md),
                PhantomButton(
                  label: _busy ? 'Checking…' : 'Confirm payment',
                  expand: true,
                  isLoading: _busy,
                  onPressed: _busy ? null : _confirmPending,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              plans.when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(message: error.toString()),
                data: (items) => methods.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorView(message: error.toString()),
                  data: (paymentMethods) {
                    if (items.isEmpty) {
                      return const PhantomCard(
                        child: Text('No CodePhantom services are currently on sale.'),
                      );
                    }

                    return Column(
                      children: [
                        for (final plan in items) ...[
                          PhantomCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _price(plan),
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                Text(
                                  _billing(plan),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                for (final method in paymentMethods.where(
                                  (item) => !plan.isSubscription || item.recurring,
                                )) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _busy ||
                                              plan.priceAmountMinor == null
                                          ? null
                                          : () => _checkout(plan, method),
                                      child: Text(
                                        plan.isSubscription
                                            ? 'Subscribe with ' + method.name
                                            : 'Pay with ' + method.name,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                                if (paymentMethods
                                    .where((item) =>
                                        !plan.isSubscription || item.recurring)
                                    .isEmpty)
                                  Text(
                                    'Checkout is not enabled for this plan yet.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.mutedText),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
