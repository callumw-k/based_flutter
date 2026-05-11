import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key, this.onSuccess});

  final void Function(bool value)? onSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (prev, next) {
      if ((prev?.value, next.value) case (SignedOut() || null, SignedIn())) onSuccess?.call(true);
    });

    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: state.isLoading
          ? const SizedBox()
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).signIn(),
                    child: const Text('Sign in with Logto'),
                  ),
                  if (state.hasError)
                    Padding(padding: const EdgeInsets.only(top: 16), child: Text('Sign in failed: ${state.error}')),
                ],
              ),
            ),
    );
  }
}
