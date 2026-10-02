import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/core/errors/failures.dart';
import 'package:env_ops/data/repositories/mock_ssh_repository.dart';
import 'package:env_ops/domain/models/server_config.dart';

void main() {
  group('SSH Host Key Verification Tests', () {
    test('successful connection test returns matching fingerprint', () async {
      final mockRepo = MockSshRepository();
      const expectedFp = 'SHA256:dGhpc2lzYWZha2Vob3N0a2V5ZmluZ2VycHJpbnQxMjM0NTY';

      final server = ServerConfig(
        id: 'srv_1',
        name: 'Production Test',
        hostname: '100.84.12.19',
        username: 'cas',
        environment: ServerEnvironment.production,
        hostKeyFingerprint: expectedFp,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final returnedFp = await mockRepo.testConnection(server);
      expect(returnedFp, equals(expectedFp));
    });

    test('host key mismatch throws HostKeyMismatchFailure with expected and received fingerprints', () async {
      final mockRepo = MockSshRepository();
      mockRepo.simulateHostKeyMismatch = true;
      const expectedFp = 'SHA256:dGhpc2lzYWZha2Vob3N0a2V5ZmluZ2VycHJpbnQxMjM0NTY';

      final server = ServerConfig(
        id: 'srv_mismatch',
        name: 'Compromised Host',
        hostname: '100.84.12.99',
        username: 'cas',
        environment: ServerEnvironment.production,
        hostKeyFingerprint: expectedFp,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await mockRepo.testConnection(server);
        fail('Expected HostKeyMismatchFailure but succeeded');
      } on HostKeyMismatchFailure catch (failure) {
        expect(failure.receivedFingerprint, equals(mockRepo.mockChangedFingerprint));
        expect(failure.host, equals('100.84.12.99'));
        expect(failure.message.contains('HOST KEY MISMATCH DETECTED'), isTrue);
      }
    });
  });
}
