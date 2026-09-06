import 'package:dio/dio.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_repository.dart';
import 'package:{{project_name.snakeCase()}}/core/network/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor(this._ref);

  final Ref _ref;

  static const _retriedKey = 'auth_retry_attempted';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await authRepository.backendToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthError = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    if (!isAuthError || alreadyRetried) {
      handler.next(err);
      return;
    }

    String? freshToken;
    try {
      freshToken = await authRepository.backendToken();
    } catch (_) {
      freshToken = null;
    }

    if (freshToken == null) {
      // Only evict if the SDK confirms there's no longer a session.
      // Network errors during refresh shouldn't sign the user out.
      if (!await authRepository.isSignedIn()) {
        _ref.read(authControllerProvider.notifier).evict();
      }
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions.copyWith(
        headers: {...err.requestOptions.headers, 'Authorization': 'Bearer $freshToken'},
        extra: {...err.requestOptions.extra, _retriedKey: true},
      );
      final response = await _ref.read(dioProvider).fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }
}
