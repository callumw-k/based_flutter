import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_repository.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/current_user_provider.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, bool>(AuthController.new);

class AuthController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => authRepository.isSignedIn();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(authRepository.isSignedIn);
  }

  Future<void> signOut() async {
    try {
      await authRepository.signOut();
    } catch (e, st) {
      talker.error('Remote sign-out failed; evicting locally anyway', e, st);
    } finally {
      state = const AsyncData(false);
      ref.invalidate(currentUserProvider);
    }
  }

  void evict() {
    state = const AsyncData(false);
    ref.invalidate(currentUserProvider);
  }
}