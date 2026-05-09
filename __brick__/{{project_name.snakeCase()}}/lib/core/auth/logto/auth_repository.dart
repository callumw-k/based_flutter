import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_user.dart';
import 'package:{{project_name.snakeCase()}}/core/env/env.dart';
import 'package:logto_dart_sdk/logto_dart_sdk.dart';

final authRepository = AuthRepository._();

class AuthRepository {
  AuthRepository._()
    : _client = LogtoClient(
        config: const LogtoConfig(endpoint: Env.logtoEndpoint, appId: Env.logtoAppId),
      );

  final LogtoClient _client;

  Future<bool> isSignedIn() => _client.isAuthenticated;

  Future<AuthUser?> currentUser() async {
    if (!await _client.isAuthenticated) return null;
    final claims = await _client.idTokenClaims;
    return claims == null
        ? null
        : AuthUser(id: claims.subject, email: claims.email, name: claims.name, picture: claims.picture);
  }

  Future<void> signIn() => _client.signIn(Env.authRedirectUri);

  Future<void> signOut() => _client.signOut(Env.authPostSignOutUri);

  Future<String?> backendToken() async {
    final token = await _client.getAccessToken();
    return token?.token;
  }
}