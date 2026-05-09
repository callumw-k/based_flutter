class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String logtoEndpoint = String.fromEnvironment('LOGTO_ENDPOINT');
  static const String logtoAppId = String.fromEnvironment('LOGTO_APP_ID');
  static const String authRedirectUri = String.fromEnvironment(
    'AUTH_REDIRECT_URI',
    defaultValue: '{{auth_redirect_scheme}}://callback',
  );
  static const String authPostSignOutUri = String.fromEnvironment(
    'AUTH_POST_SIGN_OUT_URI',
    defaultValue: '{{auth_redirect_scheme}}://home',
  );
  static const String apiResource = String.fromEnvironment('API_RESOURCE');
}