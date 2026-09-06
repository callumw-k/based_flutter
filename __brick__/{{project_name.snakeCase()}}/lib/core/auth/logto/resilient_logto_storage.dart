import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: implementation_imports
import 'package:logto_dart_sdk/src/modules/logto_storage_strategy.dart';

/// Logto's default [SecureStorageStrategy] has no `resetOnError`, so an
/// Android Keystore key that's been invalidated (e.g. after a keystore reset)
/// while the encrypted prefs file survives throws `AEADBadTagException` on
/// every read/write forever, wedging auth state permanently.
class ResilientLogtoStorage implements LogtoStorageStrategy {
  const ResilientLogtoStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) => _storage.write(key: key, value: value);
}
