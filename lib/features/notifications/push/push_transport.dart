import 'phone_alert.dart';

abstract interface class PushTransport {
  Future<bool> permission({required bool prompt});
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get tokenRefresh;
  Stream<PhoneAlert> get foreground;
  Stream<PhoneAlert> get opened;
  Future<PhoneAlert?> initialAlert();
}
