import 'package:auto_route/auto_route.dart';
{{#auth}}import 'package:flutter/foundation.dart';
{{/auth}}{{#auth}}import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_guard.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/screens/sign_in_screen.dart';
{{/auth}}import 'package:{{project_name.snakeCase()}}/core/logging/log_viewer_screen.dart';
import 'package:{{project_name.snakeCase()}}/features/example/presentation/screens/example_list_screen.dart';
{{#auth}}import 'package:flutter_riverpod/flutter_riverpod.dart';
{{/auth}}
part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
{{#auth}}  AppRouter(this._ref);

  final Ref _ref;

  late final _authGuard = AuthGuard(_ref);
{{/auth}}
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: ExampleListRoute.page,
      initial: true,
{{#auth}}      guards: [_authGuard],
{{/auth}}    ),
{{#auth}}    AutoRoute(page: SignInRoute.page),
{{/auth}}    AutoRoute(page: LogViewerRoute.page),
  ];
}
