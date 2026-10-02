import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/models/ssh_key_model.dart';
import '../../domain/repositories/ssh_key_repository.dart';
import 'storage_providers.dart';

class SshKeyListNotifier extends StateNotifier<AsyncValue<List<SshKeyModel>>> {
  final SshKeyRepository _repository;

  SshKeyListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadKeys();
  }

  Future<void> loadKeys() async {
    try {
      final keys = await _repository.getKeys();
      state = AsyncValue.data(keys);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importKey({
    required String name,
    required String privateKeyPem,
    String? passphrase,
  }) async {
    final cleanPem = privateKeyPem.trim();
    // Detect type
    String keyType = 'ED25519';
    if (cleanPem.contains('RSA')) {
      keyType = 'RSA';
    } else if (cleanPem.contains('ECDSA') || cleanPem.contains('EC PRIVATE')) {
      keyType = 'ECDSA';
    }

    // Compute preview fingerprint
    final hash = sha256.convert(utf8.encode(cleanPem));
    final previewFp = 'SHA256:${base64.encode(hash.bytes.sublist(0, 16)).replaceAll('=', '')}';

    final id = 'key_${DateTime.now().millisecondsSinceEpoch}';
    final key = SshKeyModel(
      id: id,
      name: name.trim(),
      keyType: keyType,
      publicKeyFingerprint: previewFp,
      hasPassphrase: passphrase != null && passphrase.trim().isNotEmpty,
      createdAt: DateTime.now(),
    );

    await _repository.saveKey(key, cleanPem, passphrase: passphrase?.trim());
    await loadKeys();
  }

  Future<void> deleteKey(String id) async {
    await _repository.deleteKey(id);
    await loadKeys();
  }
}

final sshKeyListProvider = StateNotifierProvider<SshKeyListNotifier, AsyncValue<List<SshKeyModel>>>((ref) {
  final repo = ref.watch(sshKeyRepositoryProvider);
  return SshKeyListNotifier(repo);
});
