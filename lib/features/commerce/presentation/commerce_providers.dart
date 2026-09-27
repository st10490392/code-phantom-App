import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_commerce_service.dart';
import '../domain/commerce_models.dart';

final commerceServiceProvider = Provider<ApiCommerceService?>((ref) {
  if (ref.watch(appEnvironmentProvider) == AppEnvironment.mock) return null;
  return ApiCommerceService(ref.watch(apiClientProvider));
});

final commercePlansProvider = FutureProvider<List<CommercePlan>>((ref) async {
  final service = ref.watch(commerceServiceProvider);
  if (service == null) return const <CommercePlan>[];
  return service.listPlans();
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethodOption>>((ref) async {
  final service = ref.watch(commerceServiceProvider);
  if (service == null) return const <PaymentMethodOption>[];
  return service.listPaymentMethods();
});


final purchaseHistoryProvider = FutureProvider<List<CommercePurchase>>((ref) async {
  final service = ref.watch(commerceServiceProvider);
  if (service == null) return const <CommercePurchase>[];
  return service.listPurchases();
});

final subscriptionsProvider = FutureProvider<List<CommerceSubscription>>((ref) async {
  final service = ref.watch(commerceServiceProvider);
  if (service == null) return const <CommerceSubscription>[];
  return service.listSubscriptions();
});
