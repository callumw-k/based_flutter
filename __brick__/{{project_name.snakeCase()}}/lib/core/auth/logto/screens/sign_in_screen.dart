import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/sign_in_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.onSuccess});

  final void Function(bool value)? onSuccess;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool isSigningIn = false;

  void signIn() async {
    setState(() => isSigningIn = true);
    try {
      await ref.read(signInControllerProvider.notifier).execute();
      widget.onSuccess?.call(true);
    } catch (e, st) {
      setState(() => isSigningIn = false);
      talker.error("Couldn't sign in user", e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInControllerProvider);

    return Scaffold(
      body: !isSigningIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(onPressed: state.isLoading ? null : signIn, child: const Text('Sign in with Logto')),
                  if (state.hasError && !state.isLoading)
                    Padding(padding: const EdgeInsets.only(top: 16), child: Text('Sign in failed: ${state.error}')),
                ],
              ),
            )
          : const SizedBox(),
    );
  }
}
