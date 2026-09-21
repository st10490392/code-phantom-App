import 'dart:async';
import 'dart:math';
import '../domain/licence.dart';
import '../domain/licence_enums.dart';
import 'licence_service.dart';

class MockLicenceService implements LicenceService {
  MockLicenceService() {
    _licences = List.of(_seed);
    _controller = StreamController<List<Licence>>.broadcast(
      onListen: () => _controller.add(List.unmodifiable(_licences)),
    );
  }

  late final List<Licence> _licences;
  late final StreamController<List<Licence>> _controller;
  final _random = Random();

  @override
  Stream<List<Licence>> watchLicences({String? userId}) {
    return _controller.stream.map(
      (all) => userId == null ? all : all.where((l) => l.userId == userId).toList(),
    );
  }

  @override
  Future<Licence> generate({
    required String userId,
    required String product,
    required LicenceDuration duration,
    required int maxDevices,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    final licence = Licence(
      id: 'lic_${now.microsecondsSinceEpoch}',
      key: _generateVisualKey(product),
      userId: userId,
      product: product,
      createdAt: now,
      expiresAt: duration.asDuration != null ? now.add(duration.asDuration!) : null,
      maxDevices: maxDevices,
      activeDevices: 0,
      status: LicenceStatus.unactivated,
    );
    _licences.add(licence);
    _controller.add(List.unmodifiable(_licences));
    return licence;
  }

  @override
  Future<Licence> revoke(String licenceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _mutate(licenceId, (l) => l.copyWith(status: LicenceStatus.revoked));
  }

  @override
  Future<Licence> renew(String licenceId, LicenceDuration duration) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _mutate(
      licenceId,
      (l) => l.copyWith(
        status: LicenceStatus.active,
        expiresAt: duration.asDuration != null
            ? DateTime.now().add(duration.asDuration!)
            : null,
      ),
    );
  }

  @override
  Future<Licence> suspend(String licenceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _mutate(licenceId, (l) => l.copyWith(status: LicenceStatus.suspended));
  }

  Licence _mutate(String id, Licence Function(Licence) update) {
    final index = _licences.indexWhere((l) => l.id == id);
    if (index == -1) throw StateError('Licence $id not found');
    final updated = update(_licences[index]);
    _licences[index] = updated;
    _controller.add(List.unmodifiable(_licences));
    return updated;
  }

  /// Visual example only — matches the brief's `CPT-SCN-7F4K-92MQ-X81P`
  /// shape. Not cryptographically meaningful; do not rely on this format.
  String _generateVisualKey(String product) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String block() => List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    final productCode = product.substring(0, min(3, product.length)).toUpperCase();
    return 'CPT-$productCode-${block()}-${block()}-${block()}';
  }

  static final List<Licence> _seed = [
    Licence(
      id: 'lic_seed_1',
      key: 'CPT-SCN-7F4K-92MQ-X81P',
      userId: 'user_scanner_client',
      product: 'Scanner',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      activatedAt: DateTime.now().subtract(const Duration(days: 89)),
      expiresAt: DateTime.now().add(const Duration(days: 22)),
      maxDevices: 2,
      activeDevices: 1,
      status: LicenceStatus.active,
    ),
    Licence(
      id: 'lic_seed_2',
      key: 'CPT-SIG-4G7L-11QW-Z90A',
      userId: 'user_signal_client',
      product: 'Signals',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      activatedAt: DateTime.now().subtract(const Duration(days: 29)),
      expiresAt: DateTime.now().add(const Duration(days: 4)),
      maxDevices: 1,
      activeDevices: 1,
      status: LicenceStatus.active,
    ),
    Licence(
      id: 'lic_seed_3',
      key: 'CPT-EA-9K2M-77TR-B44C',
      userId: 'user_ea_client',
      product: 'EA',
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
      activatedAt: DateTime.now().subtract(const Duration(days: 199)),
      expiresAt: DateTime.now().subtract(const Duration(days: 5)),
      maxDevices: 1,
      activeDevices: 0,
      status: LicenceStatus.suspended,
    ),
  ];
}
