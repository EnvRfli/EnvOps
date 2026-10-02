import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static String privateKeyStorageKey(String keyId) => 'sec_ssh_key_$keyId';
  static String passphraseStorageKey(String keyId) => 'sec_ssh_pass_$keyId';

  Future<void> savePrivateKey(String keyId, String privateKeyPem) async {
    await _storage.write(key: privateKeyStorageKey(keyId), value: privateKeyPem);
  }

  Future<String?> getPrivateKey(String keyId) async {
    return await _storage.read(key: privateKeyStorageKey(keyId));
  }

  Future<void> savePassphrase(String keyId, String passphrase) async {
    await _storage.write(key: passphraseStorageKey(keyId), value: passphrase);
  }

  Future<String?> getPassphrase(String keyId) async {
    return await _storage.read(key: passphraseStorageKey(keyId));
  }

  Future<void> deleteKeyCredentials(String keyId) async {
    await _storage.delete(key: privateKeyStorageKey(keyId));
    await _storage.delete(key: passphraseStorageKey(keyId));
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
