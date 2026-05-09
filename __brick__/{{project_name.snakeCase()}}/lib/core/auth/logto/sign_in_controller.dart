import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignInController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> execute() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await authRepository.signIn();
      await ref.read(authControllerProvider.notifier).refresh();
    });
  }
}

final signInControllerProvider = AsyncNotifierProvider.autoDispose<SignInController, void>(
  SignInController.new,
  retry: (_, _) => null,
);
