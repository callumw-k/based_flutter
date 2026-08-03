import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.cause, this.stackTrace});

  final String message;
  final int? statusCode;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

final class NetworkException extends ApiException {
  const NetworkException({required super.message, super.cause, super.stackTrace});
}

final class AuthException extends ApiException {
  const AuthException({required super.message, required int super.statusCode, super.cause, super.stackTrace});
}

final class ValidationException extends ApiException {
  const ValidationException({
    required super.message,
    required int super.statusCode,
    this.fieldErrors,
    super.cause,
    super.stackTrace,
  });

  final Map<String, List<String>>? fieldErrors;
}

final class ServerException extends ApiException {
  const ServerException({required super.message, required int super.statusCode, super.cause, super.stackTrace});
}

final class UnknownException extends ApiException {
  const UnknownException({required super.message, super.statusCode, super.cause, super.stackTrace});
}

extension DioExceptionToApi on DioException {
  ApiException toApiException() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(message: 'Request timed out', cause: this, stackTrace: stackTrace);
      case DioExceptionType.connectionError:
        return NetworkException(message: 'Could not reach server', cause: this, stackTrace: stackTrace);
      case DioExceptionType.badCertificate:
        return NetworkException(message: 'Bad certificate', cause: this, stackTrace: stackTrace);
      case DioExceptionType.cancel:
        return UnknownException(message: 'Request cancelled', cause: this, stackTrace: stackTrace);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final status = response?.statusCode;
        if (status == null) {
          return UnknownException(
            message: message ?? error?.toString() ?? 'Unknown error (${type.name})',
            cause: this,
            stackTrace: stackTrace,
          );
        }
        if (status == 401 || status == 403) {
          return AuthException(
            message: _extractServerMessage(response?.data) ?? 'Unauthorised',
            statusCode: status,
            cause: this,
            stackTrace: stackTrace,
          );
        }
        if (status == 422) {
          return ValidationException(
            message: _extractServerMessage(response?.data) ?? 'Validation failed',
            statusCode: status,
            fieldErrors: _extractFieldErrors(response?.data),
            cause: this,
            stackTrace: stackTrace,
          );
        }
        if (status >= 500) {
          return ServerException(
            message: _extractServerMessage(response?.data) ?? 'Server error',
            statusCode: status,
            cause: this,
            stackTrace: stackTrace,
          );
        }
        return UnknownException(
          message: _extractServerMessage(response?.data) ?? 'Unexpected response (status $status)',
          statusCode: status,
          cause: this,
          stackTrace: stackTrace,
        );
    }
  }
}

String? _extractServerMessage(Object? data) {
  if (data is! Map<String, Object?>) return null;
  final errors = data['errors'];
  if (errors is Map<String, Object?>) {
    final general = errors['generalErrors'];
    if (general is List && general.isNotEmpty) {
      return general.map((e) => e.toString()).join(' ');
    }
  }
  final message = data['message'];
  if (message is String && message.isNotEmpty && message != 'One or more errors occured!') {
    return message;
  }
  return null;
}

Map<String, List<String>>? _extractFieldErrors(Object? data) {
  if (data is! Map<String, Object?>) return null;
  final errors = data['errors'];
  if (errors is! Map<String, Object?>) return null;
  return {
    for (final entry in errors.entries)
      entry.key: switch (entry.value) {
        final List<Object?> list => list.map((e) => e.toString()).toList(),
        final String s => [s],
        _ => [entry.value.toString()],
      },
  };
}
