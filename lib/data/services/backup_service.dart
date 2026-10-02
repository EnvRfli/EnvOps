import 'dart:convert';
import '../../core/security/backup_crypto_service.dart';
import '../../core/security/secure_storage_service.dart';
import '../../domain/models/server_config.dart';
import '../../domain/models/ssh_key_model.dart';
import '../../domain/repositories/server_repository.dart';
import '../../domain/repositories/ssh_key_repository.dart';

class BackupResult {
  final int serverCount;
  final int keyCount;

  const BackupResult({required this.serverCount, required this.keyCount});
}

class BackupService {
  final ServerRepository serverRepository;
  final SshKeyRepository sshKeyRepository;
  final SecureStorageService secureStorage;

  BackupService({
    required this.serverRepository,
    required this.sshKeyRepository,
    required this.secureStorage,
  });

  Future<String> exportEncryptedBackup(String masterPassword) async {
    final servers = await serverRepository.getServers();
    final keys = await sshKeyRepository.getKeys();

    final exportedKeys = <Map<String, dynamic>>[];
    for (final k in keys) {
      final pem = await secureStorage.getPrivateKey(k.id);
      final passphrase = await secureStorage.getPassphrase(k.id);
      exportedKeys.add({
        'meta': k.toJson(),
        'privateKey': pem,
        'passphrase': passphrase,
      });
    }

    final exportedServers = servers.map((s) => s.toJson()).toList();

    final bundle = {
      'schema': 'env_ops_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'servers': exportedServers,
      'keys': exportedKeys,
    };

    final jsonStr = json.encode(bundle);
    return BackupCryptoService.encrypt(jsonStr, masterPassword);
  }

  Future<BackupResult> importEncryptedBackup(
    String encryptedPayload,
    String masterPassword,
  ) async {
    final jsonStr = BackupCryptoService.decrypt(encryptedPayload, masterPassword);
    final dynamic decoded = json.decode(jsonStr);

    final schema = decoded is Map<String, dynamic> ? decoded['schema'] : null;
    if (decoded is! Map<String, dynamic> || (schema != 'env_ops_backup' && schema != 'cas_ops_backup')) {
      throw const FormatException('Invalid backup structure: unrecognized schema');
    }

    final serversData = decoded['servers'] as List<dynamic>? ?? [];
    final keysData = decoded['keys'] as List<dynamic>? ?? [];

    int importedKeys = 0;
    for (final item in keysData) {
      if (item is Map<String, dynamic>) {
        final metaJson = item['meta'] as Map<String, dynamic>?;
        if (metaJson != null) {
          final keyModel = SshKeyModel.fromJson(metaJson);
          final privKey = item['privateKey'] as String? ?? '';
          final passphrase = item['passphrase'] as String?;
          await sshKeyRepository.saveKey(
            keyModel,
            privKey,
            passphrase: passphrase,
          );

          if (privKey.isNotEmpty) {
            await secureStorage.savePrivateKey(keyModel.id, privKey);
          }
          if (passphrase != null && passphrase.isNotEmpty) {
            await secureStorage.savePassphrase(keyModel.id, passphrase);
          }
          importedKeys++;
        }
      }
    }

    int importedServers = 0;
    for (final item in serversData) {
      if (item is Map<String, dynamic>) {
        final server = ServerConfig.fromJson(item);
        await serverRepository.saveServer(server);
        importedServers++;
      }
    }

    return BackupResult(serverCount: importedServers, keyCount: importedKeys);
  }
}
