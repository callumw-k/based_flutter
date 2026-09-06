class LogtoSignInException implements Exception {
  const LogtoSignInException(this.message);

  final String message;

  @override
  String toString() => 'LogtoSignInException: $message';
}
