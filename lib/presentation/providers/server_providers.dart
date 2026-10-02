import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/docker_container.dart';
import '../../domain/models/server_config.dart';
import '../../domain/models/server_profile.dart';
import '../../domain/repositories/server_repository.dart';
import 'storage_providers.dart';

enum ServerConnectionStatus {
  unknown,
  connecting,
  connected,
  disconnected,
  error;

  String get label {
    switch (this) {
      case ServerConnectionStatus.unknown:
        return 'Unknown';
      case ServerConnectionStatus.connecting:
        return 'Connecting...';
      case ServerConnectionStatus.connected:
        return 'Connected';
      case ServerConnectionStatus.disconnected:
        return 'Disconnected';
      case ServerConnectionStatus.error:
        return 'Error';
    }
  }
}

class ServerListNotifier extends StateNotifier<AsyncValue<List<ServerConfig>>> {
  final ServerRepository _repository;
  final SharedPreferences _prefs;
  final bool _isMockMode;
  static const String _mockSeededKey = 'cas_ops_mock_seeded_v1';

  ServerListNotifier(this._repository, this._prefs, this._isMockMode)
    : super(const AsyncValue.loading()) {
    loadServers();
  }

  Future<void> loadServers() async {
    try {
      var servers = await _repository.getServers();
      final hasSeeded = _prefs.getBool(_mockSeededKey) ?? false;
      if (servers.isEmpty && _isMockMode && !hasSeeded) {
        // Populate standard sample servers for initial mock dev testing only once
        servers = _getMockSeedServers();
        for (final s in servers) {
          await _repository.saveServer(s);
        }
        await _prefs.setBool(_mockSeededKey, true);
      }
      state = AsyncValue.data(servers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveServer(ServerConfig server) async {
    await _repository.saveServer(server);
    await loadServers();
  }

  Future<void> deleteServer(String id) async {
    await _repository.deleteServer(id);
    await _prefs.setBool(_mockSeededKey, true);
    await loadServers();
  }

  Future<void> clearAllServers() async {
    final servers = await _repository.getServers();
    for (final s in servers) {
      await _repository.deleteServer(s.id);
    }
    await _prefs.setBool(_mockSeededKey, true);
    await loadServers();
  }

  static List<ServerConfig> _getMockSeedServers() {
    final now = DateTime.now();
    return [
      ServerConfig(
        id: 'mock_prod_cluster',
        name: 'Production Cluster',
        hostname: '100.84.12.19',
        port: 22,
        username: 'cas',
        environment: ServerEnvironment.production,
        description:
            'Main production cluster hosting Web Services, Nginx, PostgreSQL',
        hostKeyFingerprint:
            'SHA256:dGhpc2lzYWZha2Vob3N0a2V5ZmluZ2VycHJpbnQxMjM0NTY',
        tags: ['production', 'backend', 'postgres', 'tailscale'],
        profile: const ServerProfile(
          nginxContainer: 'nginx_proxy',
          postgresContainer: 'postgres',
          redisContainer: 'redis',
          middlewareContainers: ['api_gateway_service'],
          healthEndpoints: [
            HttpHealthEndpoint(
              id: 'ep_api_health',
              name: 'Primary API Health Check',
              url: 'https://httpbin.org/status/200',
              expectedStatusCode: 200,
            ),
          ],
        ),
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      ),
      ServerConfig(
        id: 'mock_staging_mw',
        name: 'Staging Middleware',
        hostname: '100.84.12.24',
        port: 22,
        username: 'cas',
        environment: ServerEnvironment.staging,
        description: 'Integration gateway connecting microservices and cache',
        hostKeyFingerprint:
            'SHA256:dGhpc2lzYWZha2Vob3N0a2V5ZmluZ2VycHJpbnQxMjM0NTY',
        tags: ['gateway', 'middleware', 'staging'],
        profile: const ServerProfile(
          nginxContainer: 'gateway_proxy',
          redisContainer: 'redis_cache',
          healthEndpoints: [
            HttpHealthEndpoint(
              id: 'ep_staging_gateway',
              name: 'Staging Gateway Health',
              url: 'https://httpbin.org/status/503',
              expectedStatusCode: 200,
            ),
          ],
        ),
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      ),
      ServerConfig(
        id: 'mock_dev_sandbox',
        name: 'Developer Sandbox',
        hostname: '100.84.12.35',
        port: 2222,
        username: 'developer',
        environment: ServerEnvironment.development,
        description: 'Sandbox for frontend services and CI/CD runners',
        hostKeyFingerprint:
            'SHA256:dGhpc2lzYWZha2Vob3N0a2V5ZmluZ2VycHJpbnQxMjM0NTY',
        tags: ['dev', 'runner'],
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
      ),
    ];
  }
}

final serverListProvider =
    StateNotifierProvider<ServerListNotifier, AsyncValue<List<ServerConfig>>>((
      ref,
    ) {
      final repo = ref.watch(serverRepositoryProvider);
      final prefs = ref.watch(sharedPreferencesProvider);
      final isMock = ref.watch(mockModeProvider);
      return ServerListNotifier(repo, prefs, isMock);
    });

final selectedServerIdProvider = StateProvider<String?>((ref) => null);

final selectedServerProvider = Provider<ServerConfig?>((ref) {
  final id = ref.watch(selectedServerIdProvider);
  final serversAsync = ref.watch(serverListProvider);
  return serversAsync.when(
    data: (servers) => servers.where((s) => s.id == id).firstOrNull,
    loading: () => null,
    error: (err, stack) => null,
  );
});

// Server connection status tracker
class ServerConnectionStateNotifier
    extends StateNotifier<Map<String, ServerConnectionStatus>> {
  ServerConnectionStateNotifier() : super({});

  void setStatus(String serverId, ServerConnectionStatus status) {
    state = {...state, serverId: status};
  }
}

final serverConnectionStateProvider =
    StateNotifierProvider<
      ServerConnectionStateNotifier,
      Map<String, ServerConnectionStatus>
    >((ref) {
      return ServerConnectionStateNotifier();
    });

// Server Containers Provider (Fetches Docker containers on demand)
final serverContainersProvider =
    FutureProvider.family<List<DockerContainer>, ServerConfig>((
      ref,
      server,
    ) async {
      final ssh = ref.watch(sshRepositoryProvider);
      const pathPrefix =
          'export PATH=\$PATH:/usr/local/bin:/usr/bin:/bin:/snap/bin; ';
      const formatArg =
          '\'{"ID":"{{.ID}}","Names":"{{.Names}}","Image":"{{.Image}}","State":"{{.State}}","Status":"{{.Status}}","Ports":"{{.Ports}}","CreatedAt":"{{.CreatedAt}}"}\'';

      var result = await ssh.execute(
        server,
        '${pathPrefix}docker ps -a --format $formatArg',
        timeout: const Duration(seconds: 10),
      );

      // Fallback to sudo -n if non-root user doesn't have direct socket permissions
      if (result.exitCode != 0 || result.stdout.trim().isEmpty) {
        result = await ssh.execute(
          server,
          '${pathPrefix}sudo -n docker ps -a --format $formatArg',
          timeout: const Duration(seconds: 10),
        );
      }

      if (result.exitCode == 0 && result.stdout.trim().isNotEmpty) {
        final parsed = DockerContainer.parseJsonLines(result.stdout);
        if (parsed.isNotEmpty) return parsed;
      }

      // Fallback to plain docker ps -a (or sudo -n docker ps -a)
      var fallback = await ssh.execute(
        server,
        '${pathPrefix}docker ps -a',
        timeout: const Duration(seconds: 10),
      );
      if (fallback.exitCode != 0 || fallback.stdout.trim().isEmpty) {
        fallback = await ssh.execute(
          server,
          '${pathPrefix}sudo -n docker ps -a',
          timeout: const Duration(seconds: 10),
        );
      }

      if (fallback.exitCode == 0) {
        return DockerContainer.parseTableOutput(fallback.stdout);
      }

      final err = result.stderr.trim().isNotEmpty
          ? result.stderr.trim()
          : (fallback.stderr.trim().isNotEmpty
                ? fallback.stderr.trim()
                : 'Docker command failed with exit code ${result.exitCode}');
      throw Exception(err);
    });
