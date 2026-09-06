import 'package:{{project_name.snakeCase()}}/core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRouterProvider = Provider<AppRouter>(
  (ref) => AppRouter(
{{#auth}}    ref,
{{/auth}}  ),
);