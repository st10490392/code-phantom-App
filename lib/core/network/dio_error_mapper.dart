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
  final details = errorObject is Map ? errorObject['details'] : null;
  final detailsMap = details is Map<String, dynamic> ? details : null;

  return switch (status) {
    400 => ValidationException(backendMessage ?? 'Invalid request.', details: detailsMap),
    401 => AuthenticationException(backendMessage ?? 'Invalid email or password.'),
    403 => AuthorizationException(
        backendMessage ?? 'You do not have permission to perform this action.',
      ),
    >= 500 => ServerException(backendMessage ?? 'Server error. Please try again later.'),
    _ => ServerException(backendMessage ?? 'Something went wrong. Please try again.'),
  };
}
