import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_guard.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/screens/sign_in_screen.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/log_viewer_screen.dart';
import 'package:{{project_name.snakeCase()}}/features/example/presentation/screens/example_list_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter(this._ref);

  final Ref _ref;

  late final _authGuard = AuthGuard(_ref);

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: ExampleListRoute.page, initial: true, guards: [_authGuard]),
    AutoRoute(page: SignInRoute.page),
    AutoRoute(page: LogViewerRoute.page),
  ];
}
