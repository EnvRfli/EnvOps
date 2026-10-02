import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../../core/errors/failures.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/utils/shell_escaper.dart';
import '../../domain/models/command_result.dart';
import '../../domain/models/server_config.dart';
import '../../domain/repositories/ssh_repository.dart';

class DartSshInteractiveShell implements InteractiveShell {
  final SSHClient _client;
  final SSHSession _session;

  DartSshInteractiveShell(this._client, this._session);

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  void write(Uint8List data) {
    _session.write(data);
  }

  @override
  void resize(int width, int height) {
    _session.resizeTerminal(width, height);
  }

  @override
  Future<void> close() async {
    try {
      _session.close();
      _client.close();
    } catch (_) {}
  }

  @override
  Future<int?> get exitCode => _session.done.then((_) => _session.exitCode);
}

class DartSshRepository implements SshRepository {
  final SecureStorageService _secureStorage;
  final Map<String, SSHClient> _activeClients = {};
  final Map<String, List<SSHKeyPair>> _keyPairCache = {};

  DartSshRepository(this._secureStorage);

  Future<List<SSHKeyPair>> _loadKeyPairs(
    ServerConfig server, {
    String? privateKeyOverride,
    String? passphraseOverride,
  }) async {
    String? pem = privateKeyOverride;
    String? passphrase = passphraseOverride;

    if (pem == null && server.keyId != null) {
      pem = await _secureStorage.getPrivateKey(server.keyId!);
      passphrase ??= await _secureStorage.getPassphrase(server.keyId!);
    }

    if (pem == null || pem.trim().isEmpty) {
      throw const InvalidPrivateKeyFailure('No private key configured for this server.');
    }

    final cleanPem = pem.trim();
    final cleanPassphrase = (passphrase?.trim().isEmpty ?? true) ? null : passphrase?.trim();
    final cacheKey = '${server.keyId ?? 'override'}_${cleanPem.hashCode}_${cleanPassphrase.hashCode}';

    if (_keyPairCache.containsKey(cacheKey)) {
      return _keyPairCache[cacheKey]!;
    }

    try {
      // Decode OpenSSH key off the main UI isolate to prevent UI frame freezing (bcrypt KDF)
      List<SSHKeyPair> keys;
      try {
        keys = await Isolate.run(() => SSHKeyPair.fromPem(cleanPem, cleanPassphrase));
      } catch (_) {
        keys = SSHKeyPair.fromPem(cleanPem, cleanPassphrase);
      }

      if (keys.isEmpty) {
        throw const InvalidPrivateKeyFailure('No valid OpenSSH key pairs parsed from PEM data.');
      }
      _keyPairCache[cacheKey] = keys;
      return keys;
    } catch (e) {
      if (e is SshFailure) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('passphrase') || msg.contains('encrypted')) {
        throw KeyPassphraseRequiredFailure(e.toString());
      }
      throw InvalidPrivateKeyFailure(e.toString());
    }
  }

  Future<SSHClient> _connectClient(
    ServerConfig server, {
    String? privateKeyOverride,
    String? passphraseOverride,
    bool reuseExisting = true,
  }) async {
    final clientKey = '${server.id}_${server.hostname}_${server.port}_${server.username}';
    if (reuseExisting) {
      final existing = _activeClients[clientKey];
      if (existing != null && !existing.isClosed) {
        return existing;
      }
    }

    final keyPairs = await _loadKeyPairs(
      server,
      privateKeyOverride: privateKeyOverride,
      passphraseOverride: passphraseOverride,
    );

    String? presentedFingerprint;
    bool mismatchDetected = false;

    SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        server.hostname,
        server.port,
        timeout: const Duration(seconds: 10),
      );
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10061 || e.message.toLowerCase().contains('refused')) {
        throw SshGenericFailure('Connection refused by ${server.hostname}:${server.port}', e.toString());
      }
      throw HostUnreachableFailure(e.toString());
    } on TimeoutException catch (e) {
      throw ConnectionTimeoutFailure(e.toString());
    } catch (e) {
      throw HostUnreachableFailure(e.toString());
    }

    final client = SSHClient(
      socket,
      username: server.username,
      identities: keyPairs,
      onVerifyHostKey: (type, fingerprintBytes) {
        final fpString = utf8.decode(fingerprintBytes).trim();
        presentedFingerprint = fpString;

        if (server.hostKeyFingerprint != null && server.hostKeyFingerprint!.trim().isNotEmpty) {
          final expected = server.hostKeyFingerprint!.trim();
          if (expected != fpString) {
            mismatchDetected = true;
            return false; // REJECT CONNECTION!
          }
        }
        return true;
      },
    );

    try {
      await client.authenticated;
      _activeClients[clientKey] = client;
      client.done.then((_) {
        if (_activeClients[clientKey] == client) {
          _activeClients.remove(clientKey);
        }
      });
    } catch (e) {
      try {
        client.close();
      } catch (_) {}

      if (mismatchDetected && presentedFingerprint != null) {
        throw HostKeyMismatchFailure(
          expectedFingerprint: server.hostKeyFingerprint ?? '',
          receivedFingerprint: presentedFingerprint!,
          host: server.hostname,
          port: server.port,
          details: 'The remote host key has changed. Possible Man-In-The-Middle or server rebuild.',
        );
      }

      final msg = e.toString().toLowerCase();
      if (msg.contains('auth') || msg.contains('denied') || msg.contains('userauth')) {
        throw AuthenticationFailure('Public key rejected for user "${server.username}". Ensure public key is in authorized_keys.');
      }
      if (msg.contains('hostkey') || msg.contains('fingerprint') || msg.contains('verify')) {
        throw HostKeyMismatchFailure(
          expectedFingerprint: server.hostKeyFingerprint ?? '',
          receivedFingerprint: presentedFingerprint ?? 'UNKNOWN',
          host: server.hostname,
          port: server.port,
        );
      }
      throw SshGenericFailure('SSH connection/handshake failed: $e');
    }

    return client;
  }

  @override
  Future<String> testConnection(
    ServerConfig server, {
    String? privateKeyOverride,
    String? passphraseOverride,
  }) async {
    String? presentedFingerprint;
    bool mismatchDetected = false;

    final keyPairs = await _loadKeyPairs(
      server,
      privateKeyOverride: privateKeyOverride,
      passphraseOverride: passphraseOverride,
    );

    SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        server.hostname,
        server.port,
        timeout: const Duration(seconds: 8),
      );
    } on SocketException catch (e) {
      throw HostUnreachableFailure(e.toString());
    } on TimeoutException catch (e) {
      throw ConnectionTimeoutFailure(e.toString());
    } catch (e) {
      throw HostUnreachableFailure(e.toString());
    }

    final client = SSHClient(
      socket,
      username: server.username,
      identities: keyPairs,
      onVerifyHostKey: (type, fingerprintBytes) {
        final fpString = utf8.decode(fingerprintBytes).trim();
        presentedFingerprint = fpString;

        if (server.hostKeyFingerprint != null && server.hostKeyFingerprint!.trim().isNotEmpty) {
          final expected = server.hostKeyFingerprint!.trim();
          if (expected != fpString) {
            mismatchDetected = true;
            return false;
          }
        }
        return true;
      },
    );

    try {
      await client.authenticated;
      client.close();
      return presentedFingerprint ?? 'VERIFIED';
    } catch (e) {
      try {
        client.close();
      } catch (_) {}

      if (mismatchDetected && presentedFingerprint != null) {
        throw HostKeyMismatchFailure(
          expectedFingerprint: server.hostKeyFingerprint ?? '',
          receivedFingerprint: presentedFingerprint!,
          host: server.hostname,
          port: server.port,
        );
      }
      final msg = e.toString().toLowerCase();
      if (msg.contains('auth') || msg.contains('denied')) {
        throw const AuthenticationFailure('Authentication failed. Check authorized_keys on server.');
      }
      throw SshGenericFailure(e.toString());
    }
  }

  @override
  Future<CommandResult> execute(
    ServerConfig server,
    String command, {
    Duration? timeout = const Duration(seconds: 15),
  }) async {
    final startedAt = DateTime.now();
    SSHClient client;
    try {
      client = await _connectClient(server);
    } catch (e) {
      rethrow;
    }

    try {
      final session = await client.execute(command).timeout(
        timeout ?? const Duration(seconds: 15),
        onTimeout: () => throw const CommandTimeoutFailure(),
      );

      final stdoutBytes = <int>[];
      final stderrBytes = <int>[];

      final outSub = session.stdout.listen(stdoutBytes.addAll);
      final errSub = session.stderr.listen(stderrBytes.addAll);

      await session.done.timeout(
        timeout ?? const Duration(seconds: 15),
        onTimeout: () {
          session.close();
          throw const CommandTimeoutFailure();
        },
      );

      await outSub.cancel();
      await errSub.cancel();

      final finishedAt = DateTime.now();
      final duration = finishedAt.difference(startedAt);

      final stdoutText = utf8.decode(stdoutBytes, allowMalformed: true);
      final stderrText = utf8.decode(stderrBytes, allowMalformed: true);
      final exitCode = session.exitCode ?? 0;

      // Check for permission denied indicator
      if (stderrText.contains('Permission denied') || stderrText.contains('sudo: a password is required')) {
        // Return result but can be inspected
      }

      return CommandResult(
        stdout: stdoutText,
        stderr: stderrText,
        exitCode: exitCode,
        startedAt: startedAt,
        finishedAt: finishedAt,
        duration: duration,
      );
    } catch (e) {
      final clientKey = '${server.id}_${server.hostname}_${server.port}_${server.username}';
      _activeClients.remove(clientKey);
      try {
        client.close();
      } catch (_) {}
      if (e is SshFailure) rethrow;
      throw SshGenericFailure('Command execution error: $e');
    }
  }

  @override
  Future<InteractiveShell> openShell(
    ServerConfig server, {
    int width = 80,
    int height = 24,
  }) async {
    final client = await _connectClient(server);
    final session = await client.shell(
      pty: SSHPtyConfig(
        width: width,
        height: height,
        type: 'xterm-256color',
      ),
    );
    _activeClients[server.id] = client;
    return DartSshInteractiveShell(client, session);
  }

  @override
  Future<Stream<String>> streamLogs(
    ServerConfig server,
    String containerName, {
    int tail = 100,
    bool timestamps = true,
  }) async {
    final cleanContainer = ShellEscaper.sanitizeContainerName(containerName);
    final escapedContainer = ShellEscaper.escapeArg(cleanContainer);
    final cmd = 'docker logs --tail $tail ${timestamps ? "--timestamps" : ""} --follow $escapedContainer';

    final client = await _connectClient(server);
    final session = await client.execute(cmd);

    final controller = StreamController<String>(
      onCancel: () {
        session.close();
        client.close();
      },
    );

    session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(controller.add, onError: controller.addError, onDone: controller.close);

    session.stderr
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(controller.add, onError: controller.addError);

    return controller.stream;
  }

  @override
  Future<void> disconnect(String serverId) async {
    final client = _activeClients.remove(serverId);
    if (client != null) {
      try {
        client.close();
      } catch (_) {}
    }
  }
}
