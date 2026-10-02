import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/core/security/secret_redactor.dart';

void main() {
  group('SecretRedactor', () {
    test('redacts private keys', () {
      const input = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDHX0b7sZ5W8/Fk0/P0Q+YpZ6iB
-----END OPENSSH PRIVATE KEY-----
''';
      final redacted = SecretRedactor.redact(input);
      expect(redacted.contains('b3BlbnNzaC1rZXktdjE'), isFalse);
      expect(redacted.contains('[REDACTED PRIVATE KEY]'), isTrue);
    });

    test('redacts passwords and tokens in key=value format', () {
      const input = 'DB_PASSWORD=superSecret12345\nAPI_KEY=sk_live_9988776655\nTOKEN=eyJhbGciOiJIUzI1NiJ9';
      final redacted = SecretRedactor.redact(input);
      expect(redacted.contains('superSecret12345'), isFalse);
      expect(redacted.contains('sk_live_9988776655'), isFalse);
      expect(redacted.contains('PASSWORD=[REDACTED]'), isTrue);
      expect(redacted.contains('API_KEY=[REDACTED]'), isTrue);
    });

    test('redacts Authorization bearer and basic headers', () {
      const input = 'Authorization: Bearer my_secret_bearer_token_abc123';
      final redacted = SecretRedactor.redact(input);
      expect(redacted.contains('my_secret_bearer_token_abc123'), isFalse);
      expect(redacted.contains('Authorization: Bearer [REDACTED]'), isTrue);
    });

    test('redacts database and redis connection URIs', () {
      const input = 'postgres://cas_admin:secretpass123@postgres-host:5432/production_db';
      final redacted = SecretRedactor.redact(input);
      expect(redacted.contains('secretpass123'), isFalse);
      expect(redacted.contains('postgres://cas_admin:[REDACTED]@postgres-host:5432/production_db'), isTrue);
    });

    test('leaves harmless system diagnostics untouched', () {
      const input = 'Filesystem Size Used Avail Use% Mounted on\n/dev/vda1 78G 33G 45G 43% /';
      final redacted = SecretRedactor.redact(input);
      expect(redacted, equals(input));
    });
  });
}
