import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/domain/models/server_config.dart';
import 'package:env_ops/domain/models/server_profile.dart';

void main() {
  group('ServerConfig and Profile Serialization', () {
    test('serializes and deserializes ServerConfig with profile and tags', () {
      final now = DateTime.now();
      final config = ServerConfig(
        id: 'srv_test_1',
        name: 'Production Cluster',
        hostname: '100.84.12.19',
        port: 22,
        username: 'cas',
        environment: ServerEnvironment.production,
        description: 'Test cluster',
        hostKeyFingerprint: 'SHA256:abc123xyz',
        tags: ['production', 'backend', 'docker'],
        profile: const ServerProfile(
          nginxContainer: 'nginx_proxy',
          postgresContainer: 'postgres',
          redisContainer: 'redis',
        ),
        createdAt: now,
        updatedAt: now,
      );

      final json = config.toJson();
      final restored = ServerConfig.fromJson(json);

      expect(restored.id, equals(config.id));
      expect(restored.name, equals(config.name));
      expect(restored.hostname, equals(config.hostname));
      expect(restored.port, equals(22));
      expect(restored.environment, equals(ServerEnvironment.production));
      expect(restored.isProduction, isTrue);
      expect(restored.profile.nginxContainer, equals('nginx_proxy'));
      expect(restored.tags.length, equals(3));
    });

    test('parses environment labels correctly', () {
      expect(ServerEnvironment.fromString('production'), ServerEnvironment.production);
      expect(ServerEnvironment.fromString('DEVELOPMENT'), ServerEnvironment.development);
      expect(ServerEnvironment.fromString('staging'), ServerEnvironment.staging);
      expect(ServerEnvironment.fromString('monitoring'), ServerEnvironment.monitoring);
      expect(ServerEnvironment.fromString('unknown_val'), ServerEnvironment.other);
    });
  });
}
