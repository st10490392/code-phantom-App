import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ea_services.dart';
import '../data/mock_ea_services.dart';
import '../domain/ea_account.dart';

final eaServiceProvider = Provider<EAService>((ref) => MockEAService());
final eaAccountServiceProvider = Provider<EAAccountService>((ref) => MockEAAccountService());
final eaControlServiceProvider = Provider<EAControlService>((ref) => MockEAControlService());

final eaAccountListProvider = FutureProvider<List<EAAccount>>((ref) {
  return ref.watch(eaServiceProvider).listAccounts();
});

/// The signed-in client's own account — Phase 1 mock always resolves to
/// `ea_001`. Multi-account selection for OWNER/ADMIN uses [eaAccountListProvider].
final primaryEAAccountProvider = StreamProvider<EAAccount>((ref) {
  return ref.watch(eaServiceProvider).watchAccount('ea_001');
});
