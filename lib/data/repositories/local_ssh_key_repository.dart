import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/secure_storage_service.dart';
import '../../domain/models/ssh_key_model.dart';
import '../../domain/repositories/ssh_key_repository.dart';

class LocalSshKeyRepository implements SshKeyRepository {
  static const String _metadataKey = 'env_ops_ssh_key_meta_v1';
  static const String _legacyMetadataKey = 'cas_ops_ssh_key_meta_v1';
  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;

  LocalSshKeyRepository(this._prefs, this._secureStorage);

  @override
  Future<List<SshKeyModel>> getKeys() async {
    final raw = _prefs.getString(_metadataKey) ?? _prefs.getString(_legacyMetadataKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => SshKeyModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<SshKeyModel?> getKey(String id) async {
    final keys = await getKeys();
    try {
      return keys.firstWhere((k) => k.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveKey(
    SshKeyModel key,
    String privateKeyPem, {
    String? passphrase,
  }) async {
    // 1. Save secret key to secure storage
    await _secureStorage.savePrivateKey(key.id, privateKeyPem.trim());
    if (passphrase != null && passphrase.isNotEmpty) {
      await _secureStorage.savePassphrase(key.id, passphrase);
    }

    // 2. Save non-secret metadata to SharedPreferences
    final keys = await getKeys();
    final index = keys.indexWhere((k) => k.id == key.id);
    if (index >= 0) {
      keys[index] = key;
    } else {
      keys.add(key);
    }
    await _persist(keys);
  }

  @override
  Future<void> deleteKey(String id) async {
    // 1. Remove secrets from secure storage
    await _secureStorage.deleteKeyCredentials(id);

    // 2. Remove metadata
    final keys = await getKeys();
    keys.removeWhere((k) => k.id == id);
    await _persist(keys);
  }

  Future<void> _persist(List<SshKeyModel> keys) async {
    final jsonString = jsonEncode(keys.map((e) => e.toJson()).toList());
    await _prefs.setString(_metadataKey, jsonString);
  }
}
