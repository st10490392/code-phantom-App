import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/storage/secure_storage.dart';
import 'package:code_phantom_app/features/auth/data/auth_service.dart';
import 'package:code_phantom_app/features/auth/data/mock_auth_service.dart';

/// In-memory fake so this test never touches a real platform channel —
/// `flutter_secure_storage`'s default implementation would throw
/// `MissingPluginException` in a plain `flutter_test` unit test.
class _FakeSecureStorage extends Mock implements SecureStorage {}

void main() {
  late _FakeSecureStorage storage;
  late MockAuthService service;
  final memory = <String, String>{};

  setUp(() {
    memory.clear();
    storage = _FakeSecureStorage();
    when(() => storage.write(any(), any())).thenAnswer((invocation) async {
      memory[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
    });
    when(() => storage.read(any())).thenAnswer(
      (invocation) async => memory[invocation.positionalArguments[0] as String],
    );
    when(() => storage.delete(any())).thenAnswer((invocation) async {
      memory.remove(invocation.positionalArguments[0] as String);
    });
    service = MockAuthService(storage);
  });

  test('login succeeds with a valid mock account and resolves the correct role', () async {
    final session = await service.login(email: 'owner@codephantom.dev', password: 'owner123');
    expect(session.user.role, AppRole.owner);
    expect(session.user.isOwner, isTrue);
  });

  test('login fails with the wrong password', () async {
    expect(
      () => service.login(email: 'owner@codephantom.dev', password: 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('login fails for an unknown email', () async {
    expect(
      () => service.login(email: 'nobody@example.com', password: 'whatever'),
      throwsA(isA<AuthException>()),
    );
  });

  test('restoreSession returns null when nothing was persisted', () async {
    final session = await service.restoreSession();
    expect(session, isNull);
  });

  test('logout clears any persisted session', () async {
    await service.login(email: 'admin@codephantom.dev', password: 'admin123');
    await service.logout();
    final restored = await service.restoreSession();
    expect(restored, isNull);
  });
}
