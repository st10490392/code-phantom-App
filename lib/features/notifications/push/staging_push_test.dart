import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/presentation/auth_providers.dart';

bool stagingTestVisible(AppEnvironment environment, bool owner, bool android) =>
    environment == AppEnvironment.staging && owner && android;

final stagingPushTestProvider = Provider<StagingPushTestController>((ref) {
  String? owner() {
    final user = ref.read(currentUserProvider);
    return stagingTestVisible(
      ref.read(appEnvironmentProvider),
      user?.isOwner == true && user?.status == 'ACTIVE',
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    )
        ? user?.id
        : null;
  }

  final controller = StagingPushTestController(
    api: ref.watch(apiClientProvider),
    storage: ref.watch(secureStorageProvider),
    ownerId: owner,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// RC17 recovery slot: a distinct one-shot invocation, never a reset of RC16.
/// Requires backend preflight before exposing the send action.
class StagingPushTestController extends ChangeNotifier {
  StagingPushTestController({
    required this.api,
    required this.storage,
    required this.ownerId,
  });
  final ApiClient api;
  final SecureStorage storage;
  final String? Function() ownerId;
  bool ready = false;
  bool checking = false;
  bool consumed = false;
  String? message;
  String? _owner;
  bool _disposed = false;
  int _generation = 0;
  String _key(String id) => 'staging_push_test_rc17_$id';

  Future<void> load() async {
    final id = ownerId();
    if (id == _owner && ready) return;
    final generation = ++_generation;
    _owner = id;
    ready = false;
    consumed = false;
    message = null;
    try {
      final prior = id == null ? null : await storage.read(_key(id));
      if (_disposed || generation != _generation) return;
      consumed = prior != null;
      ready = false; // Fail closed until the server explicitly reports readiness.
      if (consumed) {
        message = 'Recovery test already submitted. Do not resend.';
      } else if (id != null) {
        message = 'Check staging readiness before sending.';
      }
    } catch (_) {
      consumed = true;
      message = 'Test unavailable. No notification was requested.';
    }
    if (!_disposed) notifyListeners();
  }

  /// Read-only backend authority. Missing/malformed readiness never enables send.
  Future<void> checkReadiness() async {
    final id = ownerId();
    if (id == null || id != _owner || consumed || checking) return;
    final generation = _generation;
    checking = true;
    ready = false;
    message = 'Checking staging readiness…';
    notifyListeners();
    try {
      final response = await api.get('/notifications/push/staging-test/readiness');
      if (_disposed || generation != _generation || ownerId() != id) return;
      final data = response['data'];
      ready = data is Map &&
          data['ready'] == true &&
          data['environment'] == 'staging' &&
          data['eligible_registration_count'] == 1;
      message = ready
          ? 'Staging ready. One authorized recovery attempt is available.'
          : 'Staging is not ready. No notification was requested.';
    } catch (_) {
      if (!_disposed && generation == _generation && ownerId() == id) {
        ready = false;
        message = 'Staging readiness unavailable. No notification was requested.';
      }
    } finally {
      checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> send({required bool confirmed}) async {
    final id = ownerId();
    if (!confirmed || !ready || consumed || id == null || id != _owner) return;
    consumed = true; // Synchronous latch defeats double taps before any await.
    message = 'Submitting one test notification…';
    notifyListeners();
    final generation = _generation;
    try {
      final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
      final invocation =
          '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
      await storage.write(_key(id), invocation); // Persist before network I/O.
      if (_disposed || generation != _generation || ownerId() != id) return;
      final response = await api.postOnce(
        '/notifications/push/staging-test',
        expectedUserId: id,
        body: {
          'invocation_id': invocation,
          'confirmation': 'SEND_ONE_STAGING_TEST',
        },
      );
      if (_disposed || generation != _generation || ownerId() != id) return;
      final data = response['data'];
      message = data is Map &&
              data['invocation_id'] == invocation &&
              data['provider_result'] == 'ACCEPTED' &&
              data['delivery_confirmed'] == false
          ? 'Firebase accepted the test. Check your phone; delivery is not yet confirmed.'
          : 'Test was not confirmed. Do not resend; contact CodePhantom support.';
    } catch (_) {
      if (!_disposed && generation == _generation && ownerId() == id) {
        message =
            'Test result is unavailable. It may have been sent. Do not resend.';
      }
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class StagingPushTestAction extends ConsumerWidget {
  const StagingPushTestAction({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (!stagingTestVisible(
      ref.watch(appEnvironmentProvider),
      user?.isOwner == true && user?.status == 'ACTIVE',
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    )) {
      return const SizedBox.shrink();
    }
    final controller = ref.watch(stagingPushTestProvider);
    return _TestButton(controller: controller, ownerId: user!.id);
  }
}

class _TestButton extends StatefulWidget {
  const _TestButton({required this.controller, required this.ownerId});
  final StagingPushTestController controller;
  final String ownerId;
  @override
  State<_TestButton> createState() => _TestButtonState();
}

class _TestButtonState extends State<_TestButton> {
  bool confirming = false;
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  void didUpdateWidget(covariant _TestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => Column(
          children: [
            TextButton(
              onPressed: widget.controller.consumed || widget.controller.checking
                  ? null
                  : widget.controller.checkReadiness,
              child: const Text('Check Test Readiness'),
            ),
            TextButton(
              onPressed: !widget.controller.ready ||
                      widget.controller.consumed ||
                      confirming
                  ? null
                  : () async {
                      setState(() => confirming = true);
                      final owner = widget.ownerId;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Send one staging test?'),
                          content: const Text(
                            'Send one notification to your registered Android phone. This action stays disabled after submission, even if the result is uncertain. No trade is created.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Send once'),
                            ),
                          ],
                        ),
                      );
                      if (!mounted) return;
                      if (owner == widget.ownerId) {
                        await widget.controller
                            .send(confirmed: confirmed == true);
                      }
                      if (mounted) setState(() => confirming = false);
                    },
              child: const Text('Send Test Notification'),
            ),
            if (widget.controller.message != null)
              Text(widget.controller.message!),
          ],
        ),
      );
}
