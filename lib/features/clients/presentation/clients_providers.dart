import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/client_service.dart';
import '../data/mock_client_service.dart';
import '../domain/client_profile.dart';

final clientServiceProvider = Provider<ClientService>((ref) => MockClientService());

final clientListProvider = StreamProvider<List<ClientProfile>>((ref) {
  return ref.watch(clientServiceProvider).watchClients();
});
