import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_repository.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_state.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/logto_sign_in_exception.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final user = await authRepository.currentUser();
    return user == null ? const SignedOut() : SignedIn(user);
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    try {
      await authRepository.signIn();
      final user = await authRepository.currentUser();
      if (user == null) {
        throw const LogtoSignInException('Logto sign-in returned without authenticating');
      }
      state = AsyncData(SignedIn(user));
    } catch (e, st) {
      talker.error('[AuthController] sign-in failed', e, st);
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    try {
      await authRepository.signOut();
    } catch (e, st) {
      talker.error('Remote sign-out failed; evicting locally anyway', e, st);
    } finally {
      state = const AsyncData(SignedOut());
    }
  }

  void evict() => state = const AsyncData(SignedOut());
}
