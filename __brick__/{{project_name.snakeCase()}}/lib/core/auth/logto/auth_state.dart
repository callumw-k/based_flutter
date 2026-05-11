import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_user.dart';

sealed class AuthState {
  const AuthState();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final AuthUser user;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SignedIn && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

class SignedOut extends AuthState {
  const SignedOut();
}
