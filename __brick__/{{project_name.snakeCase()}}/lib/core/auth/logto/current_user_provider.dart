import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_repository.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentUserProvider = FutureProvider<AuthUser?>((ref) async {
  final signedIn = await ref.watch(authControllerProvider.future);
  if (!signedIn) return null;
  return authRepository.currentUser();
});