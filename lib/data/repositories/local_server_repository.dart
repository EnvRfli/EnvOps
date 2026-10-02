import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/server_config.dart';
import '../../domain/repositories/server_repository.dart';

class LocalServerRepository implements ServerRepository {
  static const String _storageKey = 'env_ops_servers_v1';
  static const String _legacyStorageKey = 'cas_ops_servers_v1';
  final SharedPreferences _prefs;

  LocalServerRepository(this._prefs);

  @override
  Future<List<ServerConfig>> getServers() async {
    final raw = _prefs.getString(_storageKey) ?? _prefs.getString(_legacyStorageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ServerConfig.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ServerConfig?> getServer(String id) async {
    final servers = await getServers();
    try {
      return servers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveServer(ServerConfig server) async {
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index >= 0) {
      servers[index] = server;
    } else {
      servers.add(server);
    }
    await _persist(servers);
  }

  @override
  Future<void> deleteServer(String id) async {
    final servers = await getServers();
    servers.removeWhere((s) => s.id == id);
    await _persist(servers);
  }

  Future<void> _persist(List<ServerConfig> servers) async {
    final jsonString = jsonEncode(servers.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }
}
