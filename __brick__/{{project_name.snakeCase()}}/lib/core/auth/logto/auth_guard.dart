import 'package:auto_route/auto_route.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGuard extends AutoRouteGuard {
  AuthGuard(this._ref);

  final Ref _ref;

  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    final signedIn = await _ref.read(authControllerProvider.future).catchError((_) => false);

    if (signedIn) {
      resolver.next();
      return;
    }
    resolver.redirectUntil(SignInRoute(onSuccess: (success) => resolver.next(success)));
  }
}
