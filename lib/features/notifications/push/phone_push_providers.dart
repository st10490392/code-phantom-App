import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import 'firebase_push_transport.dart';
import 'phone_push_controller.dart';

final phonePushControllerProvider = Provider<PhonePushController>((ref) {
  final controller = PhonePushController(
    api: ref.watch(apiClientProvider),
    storage: ref.watch(secureStorageProvider),
    platform: kIsWeb ? 'WEB' : defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
    createTransport: ref.watch(appEnvironmentProvider) != AppEnvironment.mock && PhonePushConfig.configured
        ? FirebasePushTransport.create : null,
  );
  ref.onDispose(controller.dispose);
  return controller;
});
