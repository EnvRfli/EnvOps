import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/core/security/backup_crypto_service.dart';

void main() {
  group('BackupCryptoService Tests', () {
    const password = 'MySuperSecretMasterPassword123!';
    const testJson = '{"servers":[{"name":"Production Cluster","port":22}],"keys":["ssh-ed25519-test"]}';

    test('encrypts and successfully decrypts data with correct password', () {
      final encrypted = BackupCryptoService.encrypt(testJson, password);
      expect(encrypted, startsWith('ENVOPS_ENC_V1:'));
      expect(encrypted, isNot(contains(testJson)));

      final decrypted = BackupCryptoService.decrypt(encrypted, password);
      expect(decrypted, equals(testJson));
    });

    test('fails decryption when given an incorrect password', () {
      final encrypted = BackupCryptoService.encrypt(testJson, password);
      expect(
        () => BackupCryptoService.decrypt(encrypted, 'WrongPassword'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on missing version prefix', () {
      expect(
        () => BackupCryptoService.decrypt('invalid_random_string', password),
        throwsA(isA<FormatException>()),
      );
    });

    test('produces different ciphertext each time due to random IV & salt', () {
      final enc1 = BackupCryptoService.encrypt(testJson, password);
      final enc2 = BackupCryptoService.encrypt(testJson, password);
      expect(enc1, isNot(equals(enc2)));

      expect(BackupCryptoService.decrypt(enc1, password), equals(testJson));
      expect(BackupCryptoService.decrypt(enc2, password), equals(testJson));
    });
  });
}
