import 'package:dio/dio.dart';
import 'app_exceptions.dart';

/// The only place a `DioException` is inspected — everywhere else in the
/// app deals exclusively in [AppException] subtypes.
AppException mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.transformTimeout:
      return const NetworkException();
    case DioExceptionType.cancel:
      return const NetworkException('Request cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkException('Could not establish a secure connection.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final response = error.response;
  if (response == null) return const NetworkException();

  final status = response.statusCode ?? 0;
  final body = response.data;
  final errorObject = body is Map ? body['error'] : null;
  final backendMessage = errorObject is Map ? errorObject['message'] as String? : null;
  final backendCode = errorObject is Map ? errorObject['code'] as String? : null;
  final details = errorObject is Map ? errorObject['details'] : null;
  final detailsMap = details is Map<String, dynamic> ? details : null;

  return switch (status) {
    // 409 is treated the same as 400 — both are "the request as submitted
    // was rejected", shown identically as a form-level error. Note:
    // registering an email that already exists is NOT one of these — the
    // real backend deliberately returns the same 202 success as a fresh
    // registration for that case (anti-enumeration), so no client-side
    // branch is needed for it at all.
    400 || 409 => ValidationException(backendMessage ?? 'Invalid request.', details: detailsMap),
    401 => AuthenticationException(backendMessage ?? 'Invalid email or password.'),
    403 => _isEmailNotVerified(backendCode, backendMessage)
        ? EmailNotVerifiedException(backendMessage ?? 'Please verify your email before signing in.')
        : AuthorizationException(
            backendMessage ?? 'You do not have permission to perform this action.',
          ),
    >= 500 => ServerException(backendMessage ?? 'Server error. Please try again later.'),
    _ => ServerException(backendMessage ?? 'Something went wrong. Please try again.'),
  };
}

/// The real backend's unverified-account rejection on login and its
/// suspended/disabled rejection are both plain 403s with `code: "FORBIDDEN"`
/// — there is no distinct machine-readable code to switch on, only the
/// message text (`"Please verify your email address before signing in. …"`
/// as of the backend's registration/verification milestone). Matching on
/// that phrase is what actually distinguishes them today; `code ==
/// 'EMAIL_NOT_VERIFIED'` is kept as well in case a later backend change
/// adds a real machine-readable code, which would then take priority
/// automatically without a client change.
bool _isEmailNotVerified(String? code, String? message) {
  if (code == 'EMAIL_NOT_VERIFIED') return true;
  return message?.toLowerCase().contains('verify your email') ?? false;
}
