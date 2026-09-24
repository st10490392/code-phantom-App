import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/core/network/dio_error_mapper.dart';

DioException _badResponse(int statusCode, Map<String, dynamic> body) {
  final options = RequestOptions(path: '/test');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: statusCode, data: body),
  );
}

void main() {
  group('mapDioException', () {
    test('a 409 conflict is mapped the same way as a 400 (form-level rejection)', () {
      final error = _badResponse(409, {
        'error': {'code': 'CONFLICT', 'message': 'Conflict.'},
      });

      expect(mapDioException(error), isA<ValidationException>());
    });

    test(
      'a 403 whose message mentions verifying email is EmailNotVerifiedException, even '
      'with the same generic FORBIDDEN code as a suspended account (real backend shape)',
      () {
        final error = _badResponse(403, {
          'error': {
            'code': 'FORBIDDEN',
            'message':
                'Please verify your email address before signing in. Check your inbox for the '
                'confirmation link, or request a new one via POST /auth/verification/resend.',
          },
        });

        expect(mapDioException(error), isA<EmailNotVerifiedException>());
      },
    );

    test('a 403 for a suspended/disabled account (no "verify" wording) is AuthorizationException',
        () {
      final error = _badResponse(403, {
        'error': {'code': 'FORBIDDEN', 'message': 'This account has been suspended or disabled.'},
      });

      expect(mapDioException(error), isA<AuthorizationException>());
      expect(mapDioException(error), isNot(isA<EmailNotVerifiedException>()));
    });

    test('a 403 with an explicit EMAIL_NOT_VERIFIED code is recognized regardless of wording', () {
      final error = _badResponse(403, {
        'error': {'code': 'EMAIL_NOT_VERIFIED', 'message': 'Nope.'},
      });

      expect(mapDioException(error), isA<EmailNotVerifiedException>());
    });

    test('a 429 (register/resend rate limit) is RateLimitedException, not ServerException', () {
      final error = _badResponse(429, {
        'error': {'code': 'RATE_LIMITED', 'message': 'Too many requests. Please try again later.'},
      });

      final mapped = mapDioException(error);
      expect(mapped, isA<RateLimitedException>());
      expect(mapped.message, 'Too many requests. Please try again later.');
    });
  });
}
