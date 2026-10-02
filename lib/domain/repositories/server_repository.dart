import '../models/server_config.dart';

abstract class ServerRepository {
  Future<List<ServerConfig>> getServers();
  Future<ServerConfig?> getServer(String id);
  Future<void> saveServer(ServerConfig server);
  Future<void> deleteServer(String id);
}
