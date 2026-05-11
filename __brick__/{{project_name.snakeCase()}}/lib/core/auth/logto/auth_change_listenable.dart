import 'package:auto_route/auto_route.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthChangeListenable extends ReevaluateListenable {
  AuthChangeListenable(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if ((previous?.value, next.value) case (SignedIn(), SignedOut()) || (SignedOut(), SignedIn())) {
        notifyListeners();
      }
    });
  }
}

final authChangeListenableProvider = Provider<AuthChangeListenable>((ref) {
  final listenable = AuthChangeListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
});
