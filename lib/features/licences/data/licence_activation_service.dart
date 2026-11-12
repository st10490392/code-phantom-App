import '../../../core/device/device_identity.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../domain/licence.dart';

/// The device this app activates a licence on. `device_identifier` is the
/// app-generated UUID (`DeviceIdentity.deviceId`) which the backend hashes
/// before storing — never a hardware fingerprint of the phone.
class LicenceDevice {
  const LicenceDevice({required this.identifier, required this.platform, this.friendlyName});

  final String identifier;
  final String platform;
  final String? friendlyName;

  Map<String, dynamic> toBackendBody() => {
        'platform': platform,
        'device_identifier': identifier,
        if (friendlyName != null) 'friendly_name': friendlyName,
      };
}

/// Server-side activation of a purchased licence key on this device.
///
/// Adds the two operations the admin-only `LicenceService` never had:
/// `POST /licences/activate` (any authenticated user may activate their own
/// key) and `POST /licences/validate`. Activation is what makes
/// `X-CP-Device-Id` meaningful, so a successful activation turns the device
/// header on.
class ApiLicenceActivationService {
  ApiLicenceActivationService(this._client, this._identity, this._deviceBound);

  final ApiClient _client;
  final DeviceIdentity _identity;
  final DeviceBoundRegistry _deviceBound;

  Future<Licence> activate({required String licenceKey, required LicenceDevice device}) async {
    final response = await _client.post(
      '/licences/activate',
      body: {'licence_key': licenceKey, 'device': device.toBackendBody()},
    );
    final data = response['data'] as Map<String, dynamic>?;
    final licenceRow = data?['licence'] as Map<String, dynamic>?;
    if (licenceRow == null) {
      throw const ServerException('The backend did not return the activated licence.');
    }
    await _deviceBound.markBound();
    return Licence.fromBackendJson(licenceRow);
  }

  /// Re-checks a key against the server rather than trusting a local copy: an
  /// expired or revoked licence can never be presented as active from cache.
  Future<LicenceValidation> validate({required String licenceKey, bool checkThisDevice = true}) async {
    final identifier = checkThisDevice ? await _identity.deviceId() : null;
    final response = await _client.post(
      '/licences/validate',
      body: {
        'licence_key': licenceKey,
        if (identifier != null) 'device_identifier': identifier,
      },
    );
    return LicenceValidation.fromJson(response['data'] as Map<String, dynamic>? ?? const {});
  }
}

/// The backend's validation result — status and expiry come from the server.
class LicenceValidation {
  const LicenceValidation({
    required this.valid,
    required this.status,
    required this.service,
    this.expiresAt,
    this.deviceRecognized,
  });

  final bool valid;
  final String status;
  final String service;
  final DateTime? expiresAt;
  final bool? deviceRecognized;

  factory LicenceValidation.fromJson(Map<String, dynamic> json) => LicenceValidation(
        valid: json['valid'] == true,
        status: json['status'] as String? ?? 'UNKNOWN',
        service: json['service'] as String? ?? 'UNKNOWN',
        expiresAt: json['expiresAt'] is String ? DateTime.tryParse(json['expiresAt'] as String) : null,
        deviceRecognized: json['deviceRecognized'] as bool?,
      );

  /// EA and SIGNALS are distinct backend services; the UI never folds the two
  /// labels into one.
  bool get isSignals => service.toUpperCase() == 'SIGNALS';
  bool get isEa => service.toUpperCase() == 'EA';
}
