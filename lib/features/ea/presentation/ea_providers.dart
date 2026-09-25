import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_ea_service.dart';
import '../data/ea_services.dart';
import '../data/mock_ea_services.dart';
import '../domain/ea_account.dart';

final eaServiceProvider = Provider<EAService>((ref) =>
    ref.watch(appEnvironmentProvider) == AppEnvironment.mock
        ? MockEAService()
        : ApiEAService(ref.watch(apiClientProvider)),
final eaAccountServiceProvider = Provider<EAAccountService>((ref) =>
    ref.watch(appEnvironmentProvider) == AppEnvironment.mock
        ? MockEAAccountService()
        : ApiEAService(ref.watch(apiClientProvider)),
final eaControlServiceProvider = Provider<EAControlService>((ref) =>
    ref.watch(appEnvironmentProvider) == AppEnvironment.mock
        ? MockEAControlService()
        : ApiEAService(ref.watch(apiClientProvider)),

final eaAccountListProvider = FutureProvider<List<EAAccount>>((ref) {
  return ref.watch(eaServiceProvider).listAccounts();
});

/// Uses the first actual account; a new installation has no EA account yet.
final primaryEAAccountProvider = StreamProvider<EAAccount?>((ref) async* {
  final service = ref.watch(eaServiceProvider);
  final accounts = await service.listAccounts();
  if (accounts.isEmpty) {
    yield null;
    return;
  }
  yield* service.watchAccount(accounts.first.accountId);
});
