import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/core/security/secure_storage_service.dart';
import 'package:env_ops/data/services/backup_service.dart';
import 'package:env_ops/domain/models/server_config.dart';
import 'package:env_ops/domain/models/ssh_key_model.dart';
import 'package:env_ops/domain/repositories/server_repository.dart';
import 'package:env_ops/domain/repositories/ssh_key_repository.dart';

class InMemoryServerRepository implements ServerRepository {
  final Map<String, ServerConfig> _servers = {};

  @override
  Future<List<ServerConfig>> getServers() async => _servers.values.toList();

  @override
  Future<ServerConfig?> getServer(String id) async => _servers[id];

  @override
  Future<void> saveServer(ServerConfig server) async {
    _servers[server.id] = server;
  }

  @override
  Future<void> deleteServer(String id) async {
    _servers.remove(id);
  }
}

class InMemorySshKeyRepository implements SshKeyRepository {
  final Map<String, SshKeyModel> _keys = {};

  @override
  Future<List<SshKeyModel>> getKeys() async => _keys.values.toList();

  @override
  Future<SshKeyModel?> getKey(String id) async => _keys[id];

  @override
  Future<void> saveKey(
    SshKeyModel key,
    String privateKeyPem, {
    String? passphrase,
  }) async {
    _keys[key.id] = key;
  }

  @override
  Future<void> deleteKey(String id) async {
    _keys.remove(id);
  }
}

class InMemorySecureStorageService extends SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> savePrivateKey(String keyId, String privateKeyPem) async {
    _storage['key_$keyId'] = privateKeyPem;
  }

  @override
  Future<String?> getPrivateKey(String keyId) async => _storage['key_$keyId'];

  @override
  Future<void> savePassphrase(String keyId, String passphrase) async {
    _storage['pass_$keyId'] = passphrase;
  }

  @override
  Future<String?> getPassphrase(String keyId) async => _storage['pass_$keyId'];

  @override
  Future<void> deleteKeyCredentials(String keyId) async {
    _storage.remove('key_$keyId');
    _storage.remove('pass_$keyId');
  }
}

void main() {
  group('BackupService Export and Import Integration Tests', () {
    late InMemoryServerRepository serverRepo;
    late InMemorySshKeyRepository keyRepo;
    late InMemorySecureStorageService secureStorage;
    late BackupService backupService;

    setUp(() {
      serverRepo = InMemoryServerRepository();
      keyRepo = InMemorySshKeyRepository();
      secureStorage = InMemorySecureStorageService();
      backupService = BackupService(
        serverRepository: serverRepo,
        sshKeyRepository: keyRepo,
        secureStorage: secureStorage,
      );
    });

    test('exports full backup and imports onto clean repository correctly', () async {
      // 1. Populate source data (e.g. on emulator)
      final now = DateTime.now();
      final key1 = SshKeyModel(
        id: 'key_1',
        name: 'Demo Key',
        keyType: 'ED25519',
        publicKeyFingerprint: 'SHA256:abc',
        hasPassphrase: true,
        createdAt: now,
      );
      await keyRepo.saveKey(key1, '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----', passphrase: 'myKeyPassphrase');
      await secureStorage.savePrivateKey('key_1', '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----');
      await secureStorage.savePassphrase('key_1', 'myKeyPassphrase');

      final server1 = ServerConfig(
        id: 'srv_1',
        name: 'Demo Production',
        hostname: '10.0.0.10',
        port: 22,
        username: 'root',
        environment: ServerEnvironment.production,
        keyId: 'key_1',
        hostKeyFingerprint: 'SHA256:fakeFingerprintForUnitTesting1234567890=',
        createdAt: now,
        updatedAt: now,
      );
      final server2 = ServerConfig(
        id: 'srv_2',
        name: 'Demo Development',
        hostname: '10.0.0.20',
        port: 11022,
        username: 'cas',
        environment: ServerEnvironment.development,
        keyId: 'key_1',
        createdAt: now,
        updatedAt: now,
      );
      await serverRepo.saveServer(server1);
      await serverRepo.saveServer(server2);

      // 2. Export with master password
      const masterPassword = 'MasterSyncPassword2026!';
      final encryptedPayload = await backupService.exportEncryptedBackup(masterPassword);
      expect(encryptedPayload, startsWith('ENVOPS_ENC_V1:'));

      // 3. Create fresh new destination target (e.g. physical phone)
      final destServerRepo = InMemoryServerRepository();
      final destKeyRepo = InMemorySshKeyRepository();
      final destSecureStorage = InMemorySecureStorageService();
      final destBackupService = BackupService(
        serverRepository: destServerRepo,
        sshKeyRepository: destKeyRepo,
        secureStorage: destSecureStorage,
      );

      // 4. Import on target phone
      final result = await destBackupService.importEncryptedBackup(encryptedPayload, masterPassword);
      expect(result.serverCount, equals(2));
      expect(result.keyCount, equals(1));

      // 5. Verify restored data on target phone
      final restoredServers = await destServerRepo.getServers();
      expect(restoredServers.length, equals(2));
      expect(restoredServers.any((s) => s.name == 'Demo Production' && s.port == 22), isTrue);
      expect(restoredServers.any((s) => s.name == 'Demo Development' && s.port == 11022 && s.username == 'cas'), isTrue);

      final restoredKeys = await destKeyRepo.getKeys();
      expect(restoredKeys.length, equals(1));
      expect(restoredKeys.first.name, equals('Demo Key'));

      final restoredPem = await destSecureStorage.getPrivateKey('key_1');
      expect(restoredPem, contains('-----BEGIN OPENSSH PRIVATE KEY-----'));

      final restoredPassphrase = await destSecureStorage.getPassphrase('key_1');
      expect(restoredPassphrase, equals('myKeyPassphrase'));
    });
  });
}
