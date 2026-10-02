import 'dart:typed_data';
import '../models/command_result.dart';
import '../models/server_config.dart';

abstract class InteractiveShell {
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;
  void write(Uint8List data);
  void resize(int width, int height);
  Future<void> close();
  Future<int?> get exitCode;
}

abstract class SshRepository {
  /// Tests SSH connection and host key verification for a server.
  /// Throws typed [SshFailure] if verification fails, timeout, or auth error.
  Future<String> testConnection(
    ServerConfig server, {
    String? privateKeyOverride,
    String? passphraseOverride,
  });

  /// Executes a single command on the remote server and returns the result.
  Future<CommandResult> execute(
    ServerConfig server,
    String command, {
    Duration? timeout,
  });

  /// Opens an interactive PTY shell session on the remote server.
  Future<InteractiveShell> openShell(
    ServerConfig server, {
    int width = 80,
    int height = 24,
  });

  /// Streams remote container logs (e.g. docker logs --follow).
  /// Yields decoded string chunks.
  Future<Stream<String>> streamLogs(
    ServerConfig server,
    String containerName, {
    int tail = 100,
    bool timestamps = true,
  });

  /// Disconnects any cached or open connections for this server.
  Future<void> disconnect(String serverId);
}
