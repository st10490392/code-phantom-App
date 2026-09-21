import 'dart:async';
import '../../../core/permissions/permission.dart';
import '../../../core/permissions/permission_set.dart';
import '../domain/client_profile.dart';
import 'client_service.dart';

class MockClientService implements ClientService {
  MockClientService() {
    _clients = List.of(_seed);
  }

  late final List<ClientProfile> _clients;

  /// See `mock_scanner_service.dart` for why this is a payload-less "ping"
  /// rather than a plain `broadcast(onListen: ...)`.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<List<ClientProfile>> watchClients() async* {
    yield List.unmodifiable(_clients);
    yield* _changes.stream.map((_) => List.unmodifiable(_clients));
  }

  @override
  Future<void> setServiceAccess(String userId, PermissionSet permissions) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _mutate(userId, (c) => c.copyWith(servicePermissions: permissions));
  }

  @override
  Future<void> suspend(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _mutate(userId, (c) => c.copyWith(status: ClientAccountStatus.suspended));
  }

  @override
  Future<void> reactivate(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _mutate(userId, (c) => c.copyWith(status: ClientAccountStatus.active));
  }

  void _mutate(String userId, ClientProfile Function(ClientProfile) update) {
    final index = _clients.indexWhere((c) => c.userId == userId);
    if (index == -1) throw StateError('Client $userId not found');
    _clients[index] = update(_clients[index]);
    _changes.add(null);
  }

  static final List<ClientProfile> _seed = [
    ClientProfile(
      userId: 'user_scanner_client',
      name: 'Scanner-Only Client',
      email: 'scanner.client@codephantom.dev',
      status: ClientAccountStatus.active,
      joinedAt: DateTime.now().subtract(const Duration(days: 120)),
      lastLoginAt: DateTime.now().subtract(const Duration(hours: 5)),
      servicePermissions: const PermissionSet({Permission.scannerAccess}),
      licenceStatus: 'ACTIVE',
      licenceExpiry: DateTime.now().add(const Duration(days: 22)),
      registeredDevices: [
        RegisteredDevice(id: 'dev_1', label: 'Pixel 8', lastSeen: DateTime.now().subtract(const Duration(hours: 5))),
      ],
    ),
    ClientProfile(
      userId: 'user_signal_client',
      name: 'Signals-Only Client',
      email: 'signal.client@codephantom.dev',
      status: ClientAccountStatus.active,
      joinedAt: DateTime.now().subtract(const Duration(days: 60)),
      lastLoginAt: DateTime.now().subtract(const Duration(days: 1)),
      servicePermissions: const PermissionSet({Permission.signalsAccess}),
      licenceStatus: 'ACTIVE',
      licenceExpiry: DateTime.now().add(const Duration(days: 4)),
      registeredDevices: [
        RegisteredDevice(id: 'dev_2', label: 'iPhone 15', lastSeen: DateTime.now().subtract(const Duration(days: 1))),
      ],
    ),
    ClientProfile(
      userId: 'user_ea_client',
      name: 'EA-Only Client',
      email: 'ea.client@codephantom.dev',
      status: ClientAccountStatus.suspended,
      joinedAt: DateTime.now().subtract(const Duration(days: 200)),
      lastLoginAt: DateTime.now().subtract(const Duration(days: 30)),
      servicePermissions: const PermissionSet({Permission.eaAccess}),
      licenceStatus: 'SUSPENDED',
      licenceExpiry: DateTime.now().subtract(const Duration(days: 5)),
      registeredDevices: const [],
    ),
  ];
}
