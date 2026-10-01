import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/device_identity_store.dart';
import '../domain/licensing_models.dart';

class LicensingService {
  const LicensingService(this._client, this._deviceIdentity);

  final ApiClient _client;
  final DeviceIdentityStore _deviceIdentity;

  Future<ActivationResult> activate(String activationKey) async {
    final installationId = await _deviceIdentity.getOrCreateInstallationId();
    final package = await PackageInfo.fromPlatform();
    final response = await _client.post(
      '/me/activation',
      body: {
        'activation_key': activationKey.trim().toUpperCase(),
        'device': {
          'platform': _platform,
          'installation_id': installationId,
          'display_name': _platform == 'WEB' ? 'Web app' : 'CodePhantom app',
          'app_version': '${package.version}+${package.buildNumber}',
        },
      },
    );
    final data = response['data'] as Map<String, dynamic>;
    final device = data['device'] as Map<String, dynamic>;
    final deviceId = device['id'] as String;
    await _deviceIdentity.saveServerDeviceId(deviceId);

    final entitlements =
        ((data['entitlements_granted'] as List?) ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);
    return ActivationResult(deviceId: deviceId, entitlements: entitlements);
  }

  Future<List<CoreLicence>> listLicences() async {
    final response = await _client.get(
      '/admin/platform/licences',
      query: {'limit': 100, 'offset': 0},
    );
    final rows = response['data'] as List? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CoreLicence.fromJson)
        .toList(growable: false);
  }

  Future<GeneratedActivationKey> generateScannerKey({
    int deviceLimit = 1,
  }) async {
    final response = await _client.post(
      '/admin/platform/licences/keys',
      body: {
        'plan_code': 'scanner_v1',
        'count': 1,
        'device_limit': deviceLimit,
        'source': 'ADMIN',
      },
    );
    final rows = response['data'] as List? ?? const <dynamic>[];
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw StateError('The server did not return an activation key.');
    }
    return GeneratedActivationKey.fromJson(
      rows.first as Map<String, dynamic>,
    );
  }

  String get _platform {
    if (kIsWeb) return 'WEB';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'ANDROID',
      TargetPlatform.iOS => 'IOS',
      TargetPlatform.windows => 'WINDOWS',
      TargetPlatform.macOS => 'MACOS',
      TargetPlatform.linux => 'LINUX',
      TargetPlatform.fuchsia => 'ANDROID',
    };
  }
}
