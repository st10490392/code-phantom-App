import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'phone_alert.dart';
import 'push_transport.dart';

class PhonePushConfig {
  static const enabled = bool.fromEnvironment('PUSH_ENABLED');
  static const projectId = String.fromEnvironment('PUSH_FIREBASE_PROJECT_ID');
  static const appId = String.fromEnvironment('PUSH_FIREBASE_APP_ID');
  static const apiKey = String.fromEnvironment('PUSH_FIREBASE_API_KEY');
  static const senderId = String.fromEnvironment('PUSH_FIREBASE_SENDER_ID');
  static const vapidKey = String.fromEnvironment('PUSH_WEB_VAPID_KEY');
  static bool get supported => kIsWeb ||
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  static bool get configured => enabled && supported &&
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android ||
       [projectId, appId, apiKey, senderId].every((value) => value.isNotEmpty) && (!kIsWeb || vapidKey.isNotEmpty));
}

/// Android reads generated native resources from google-services.json.
/// This runs before handlers are registered, without prompting permission.
Future<void> initializePushFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(options: const FirebaseOptions(
      projectId: PhonePushConfig.projectId, appId: PhonePushConfig.appId,
      apiKey: PhonePushConfig.apiKey, messagingSenderId: PhonePushConfig.senderId,
      iosBundleId: 'dev.codephantom.codePhantomApp',
    ),);
  }
}

@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  await initializePushFirebase();
  // Notification payloads are displayed by the OS. Never display another
  // notification, fetch trading data, or trust payloads as authorization here.
}

class FirebasePushTransport implements PushTransport {
  FirebasePushTransport(this._messaging);
  final FirebaseMessaging _messaging;

  static Future<PushTransport> create() async {
    await initializePushFirebase();
    if (kIsWeb && !await FirebaseMessaging.instance.isSupported()) {
      throw UnsupportedError('Web notifications are not supported here.');
    }
    final messaging = FirebaseMessaging.instance;
    // Foreground alerts use the app banner on both platforms, once.
    await messaging.setForegroundNotificationPresentationOptions();
    return FirebasePushTransport(messaging);
  }

  @override
  Future<bool> permission({required bool prompt}) async {
    final settings = prompt ? await _messaging.requestPermission() : await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    await _messaging.setAutoInitEnabled(true);
    // APNs registration can finish after sign-in; resume retries safely.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && await _messaging.getAPNSToken() == null) return null;
    return _messaging.getToken(vapidKey: kIsWeb ? PhonePushConfig.vapidKey : null);
  }

  @override
  Future<void> deleteToken() async {
    await _messaging.setAutoInitEnabled(false);
    await _messaging.deleteToken();
  }

  Stream<PhoneAlert> _alerts(Stream<RemoteMessage> stream) => stream
      .map((message) => PhoneAlert.parse(message.data))
      .where((alert) => alert != null)
      .cast<PhoneAlert>();
  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;
  @override
  Stream<PhoneAlert> get foreground => _alerts(FirebaseMessaging.onMessage);
  @override
  Stream<PhoneAlert> get opened => _alerts(FirebaseMessaging.onMessageOpenedApp);
  @override
  Future<PhoneAlert?> initialAlert() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PhoneAlert.parse(message.data);
  }
}
