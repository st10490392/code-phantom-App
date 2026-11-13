import '../../../core/config/api_config.dart';
import '../../../core/device/device_identity.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/network/bridge_client.dart';
import '../../../core/storage/bridge_credentials.dart';

/// Activation of a trading-bridge licence key (`POST /api/v1/license/activate`)
/// and the `SIGNALS` key the live feed authenticates with.
///
/// These are bridge keys, not the Node backend's licence records — a second,
/// separate licence system whose binding is a hardware id rather than a device
/// row. The plaintext key is sent once and kept in secure storage, because the
/// bridge needs it in the stream query string on every reconnect; it is never
/// logged, displayed or included in an exception message.
class BridgeLicenceService {
  BridgeLicenceService({
    required BridgeClient client,
    required BridgeCredentialStorage credentials,
    required DeviceIdentity identity,
  }) : _client = client,
       _credentials = credentials,
       _identity = identity;

  final BridgeClient _client;
  final BridgeCredentialStorage _credentials;
  final DeviceIdentity _identity;

  /// This app activates `SIGNALS` keys only. An `EA` key authorizes the
  /// operator's own daemon (the dispatch gate in `signal_pipeline.dispatch()`),
  /// never a phone, and activation is one-time and hardware-bound — activating
  /// one here would burn a key that can never authorize this client. The
  /// bridge's own cross-service check remains the authority; this is the
  /// client refusing to do something that cannot help the user.
  Future<BridgeLicenceActivation> activate({required String key, required String serviceType}) async {
    if (serviceType != 'SIGNALS') {
      throw const ValidationException(
        'This app activates SIGNALS keys only. An EA key authorizes the trading host, not a phone.',
      );
    }
    final hardwareId = await _identity.hardwareId();
    final response = await _client.post(
      '/license/activate',
      body: {'key': key, 'service_type': serviceType, 'hardware_id': hardwareId},
    );
    if (serviceType == 'SIGNALS') {
      await _credentials.saveSignalsKey(key);
    }
    return BridgeLicenceActivation.fromJson(response);
  }

  Future<bool> hasSignalsKey() async => await _credentials.readSignalsKey() != null;

  Future<void> forgetSignalsKey() => _credentials.clearSignalsKey();

  /// The daemon-side view: `{ea, signals}` is the operator host's own key
  /// validity — whether the daemon is licensed to dispatch — not this
  /// account's entitlement, which comes from `GET /me`.
  Future<BridgeLicenseValidity> validity() async =>
      BridgeLicenseValidity.fromJson(await _client.get('/license/status'));
}

class BridgeLicenceActivation {
  const BridgeLicenceActivation({
    required this.serviceType,
    required this.status,
    required this.hardwareId,
    this.activatedAt,
  });

  final String serviceType;
  final String status;

  /// The bridge's hardware binding for this key — an identifier, not a secret,
  /// and safe to show on the device screen.
  final String hardwareId;
  final DateTime? activatedAt;

  factory BridgeLicenceActivation.fromJson(Map<String, dynamic> json) => BridgeLicenceActivation(
        serviceType: json['service_type'] as String? ?? 'UNKNOWN',
        status: json['status'] as String? ?? 'UNKNOWN',
        hardwareId: json['hardware_id'] as String? ?? '',
        activatedAt: json['activated_at'] is String ? DateTime.tryParse(json['activated_at'] as String) : null,
      );
}

class BridgeLicenseValidity {
  const BridgeLicenseValidity({required this.eaLicensed, required this.signalsLicensed});

  final bool eaLicensed;
  final bool signalsLicensed;

  factory BridgeLicenseValidity.fromJson(Map<String, dynamic> json) => BridgeLicenseValidity(
        eaLicensed: json['ea'] == true,
        signalsLicensed: json['signals'] == true,
      );
}

/// Build-flag gate for the bridge activation surface, mirroring
/// `SCANNER_REVIEW_ACTIONS`: a build with no configured bridge never offers an
/// action that cannot possibly succeed.
bool bridgeActivationAvailable() => ApiConfig.bridgeConfigured;
