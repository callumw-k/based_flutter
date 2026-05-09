import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_token_interceptor.dart';
import 'package:{{project_name.snakeCase()}}/core/env/env.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(AuthTokenInterceptor(ref));
  dio.interceptors.add(
    TalkerDioLogger(
      talker: talker,
      settings: const TalkerDioLoggerSettings(
        printErrorMessage: true,
        printErrorData: true,
        printRequestHeaders: kDebugMode,
        printResponseHeaders: kDebugMode,
        printRequestData: kDebugMode,
        printResponseData: kDebugMode,
        printResponseMessage: kDebugMode,
        printErrorHeaders: kDebugMode,
      ),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
