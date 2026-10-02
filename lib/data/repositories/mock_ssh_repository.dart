import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../domain/models/command_result.dart';
import '../../domain/models/server_config.dart';
import '../../domain/repositories/ssh_repository.dart';

class MockInteractiveShell implements InteractiveShell {
  final StreamController<Uint8List> _stdoutController = StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _stderrController = StreamController<Uint8List>.broadcast();
  final ServerConfig server;
  final StringBuffer _inputBuffer = StringBuffer();

  MockInteractiveShell(this.server) {
    // Send initial greeting and shell prompt
    Future.delayed(const Duration(milliseconds: 100), () {
      _writeText('\x1B[1;32mWelcome to Ubuntu 24.04.1 LTS (GNU/Linux 6.8.0-40-generic x86_64)\x1B[0m\r\n');
      _writeText('System information as of ${DateTime.now().toUtc().toIso8601String()}\r\n\r\n');
      _writeText('  System load:  0.42, 0.35, 0.28\r\n');
      _writeText('  Usage of /:   42.1% of 78.20GB\r\n');
      _writeText('  Memory usage: 52% (4160Mi / 7954Mi)\r\n');
      _writeText('  Processes:    128 running\r\n\r\n');
      _printPrompt();
    });
  }

  void _writeText(String text) {
    _stdoutController.add(Uint8List.fromList(utf8.encode(text)));
  }

  void _printPrompt() {
    _writeText('\x1B[1;34m${server.username}@${server.name.toLowerCase().replaceAll(' ', '-')}\x1B[0m:\x1B[1;36m~\x1B[0m\$ ');
  }

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  void write(Uint8List data) {
    final text = utf8.decode(data, allowMalformed: true);
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '\r' || char == '\n') {
        _writeText('\r\n');
        final cmd = _inputBuffer.toString().trim();
        _inputBuffer.clear();
        _handleCommand(cmd);
        _printPrompt();
      } else if (char == '\x7F' || char == '\b') {
        if (_inputBuffer.isNotEmpty) {
          final s = _inputBuffer.toString();
          _inputBuffer.clear();
          _inputBuffer.write(s.substring(0, s.length - 1));
          _writeText('\b \b');
        }
      } else if (char == '\x03') { // CTRL+C
        _writeText('^C\r\n');
        _inputBuffer.clear();
        _printPrompt();
      } else if (char == '\x0c') { // CTRL+L
        _writeText('\x1B[2J\x1B[H');
        _printPrompt();
      } else {
        _inputBuffer.write(char);
        _writeText(char); // echo
      }
    }
  }

  void _handleCommand(String cmd) {
    if (cmd.isEmpty) return;
    if (cmd == 'docker ps') {
      _writeText('CONTAINER ID   IMAGE                 COMMAND                  CREATED        STATUS                    PORTS                    NAMES\r\n');
      _writeText('e7a8f192b0c1   nginx:alpine          "/docker-entrypoint.…"   2 days ago     Up 2 days                 0.0.0.0:80->80/tcp       nginx_proxy\r\n');
      _writeText('4b1c8f309d2a   postgres:16-alpine    "docker-entrypoint.s…"   5 days ago     Up 5 days                 0.0.0.0:5432->5432/tcp   postgres\r\n');
      _writeText('98f23a100ce4   app/api-gateway:1.0   "/entrypoint.sh"         3 hours ago    Restarting (1) 20s ago                             api_gateway_service\r\n');
      _writeText('109bcfa37e21   redis:7-alpine        "docker-entrypoint.s…"   2 weeks ago    Up 2 weeks                0.0.0.0:6379->6379/tcp   redis\r\n');
    } else if (cmd == 'uptime') {
      _writeText(' 09:31:45 up 45 days, 14:22,  2 users,  load average: 0.42, 0.35, 0.28\r\n');
    } else if (cmd == 'free -h') {
      _writeText('               total        used        free      shared  buff/cache   available\r\n');
      _writeText('Mem:           7.8Gi       4.1Gi       1.2Gi       140Mi       2.5Gi       3.4Gi\r\n');
      _writeText('Swap:          4.0Gi       256Mi       3.7Gi\r\n');
    } else if (cmd == 'df -h') {
      _writeText('Filesystem      Size  Used Avail Use% Mounted on\r\n');
      _writeText('/dev/vda1        78G   33G   45G  43% /\r\n');
      _writeText('tmpfs           3.9G     0  3.9G   0% /dev/shm\r\n');
    } else {
      _writeText('Linux test shell executed: $cmd\r\n');
    }
  }

  @override
  void resize(int width, int height) {}

  @override
  Future<void> close() async {
    await _stdoutController.close();
    await _stderrController.close();
  }

  @override
  Future<int?> get exitCode => Future.value(0);
}

class MockSshRepository implements SshRepository {
  bool simulateHostKeyMismatch = false;
  String mockExpectedFingerprint = 'SHA256:dGhpc2lzYWZha2Vob3N0a2V5ZmluZ2VycHJpbnQxMjM0NTY';
  String mockChangedFingerprint = 'SHA256:TUlTTUFUQ0hFREhPU1RLRVlGSU5HRVJQUklOVDk5OTk5';

  @override
  Future<String> testConnection(
    ServerConfig server, {
    String? privateKeyOverride,
    String? passphraseOverride,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (simulateHostKeyMismatch || server.hostKeyFingerprint == 'TRIGGER_MISMATCH') {
      throw HostKeyMismatchFailure(
        expectedFingerprint: server.hostKeyFingerprint ?? mockExpectedFingerprint,
        receivedFingerprint: mockChangedFingerprint,
        host: server.hostname,
        port: server.port,
        details: 'Simulated mismatch: The host identity changed or potential MITM blocked.',
      );
    }

    return server.hostKeyFingerprint?.isNotEmpty == true
        ? server.hostKeyFingerprint!
        : mockExpectedFingerprint;
  }

  @override
  Future<CommandResult> execute(
    ServerConfig server,
    String command, {
    Duration? timeout,
  }) async {
    final startedAt = DateTime.now();
    await Future.delayed(const Duration(milliseconds: 350));
    final trimmed = command.trim();

    String stdout = '';
    String stderr = '';
    int exitCode = 0;

    if (trimmed.startsWith('uptime')) {
      stdout = ' 09:31:45 up 45 days, 14:22,  2 users,  load average: 0.42, 0.35, 0.28\n';
    } else if (trimmed.startsWith('free -h')) {
      stdout = '               total        used        free      shared  buff/cache   available\n'
          'Mem:           7.8Gi       4.1Gi       1.2Gi       140Mi       2.5Gi       3.4Gi\n'
          'Swap:          4.0Gi       256Mi       3.7Gi\n';
    } else if (trimmed.startsWith('df -h')) {
      stdout = 'Filesystem      Size  Used Avail Use% Mounted on\n'
          '/dev/vda1        78G   33G   45G  43% /\n'
          'tmpfs           3.9G     0  3.9G   0% /dev/shm\n';
    } else if (trimmed.startsWith('df -i')) {
      stdout = 'Filesystem       Inodes  IUsed   IFree IUse% Mounted on\n'
          '/dev/vda1       5242880 342110 4900770    7% /\n';
    } else if (trimmed.contains('docker ps') && trimmed.contains('json')) {
      stdout = '{"ID":"e7a8f192b0c1","Names":"nginx_proxy","Image":"nginx:alpine","State":"running","Status":"Up 2 days","Ports":"0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp","CreatedAt":"2026-09-30 10:00:00"}\n'
          '{"ID":"4b1c8f309d2a","Names":"postgres","Image":"postgres:16-alpine","State":"running","Status":"Up 5 days (healthy)","Ports":"0.0.0.0:5432->5432/tcp","CreatedAt":"2026-09-27 08:30:00"}\n'
          '{"ID":"98f23a100ce4","Names":"api_gateway_service","Image":"app/api-gateway:1.0","State":"restarting","Status":"Restarting (1) 20 seconds ago","Ports":"","CreatedAt":"2026-10-02 06:15:00"}\n'
          '{"ID":"109bcfa37e21","Names":"redis","Image":"redis:7-alpine","State":"running","Status":"Up 2 weeks","Ports":"0.0.0.0:6379->6379/tcp","CreatedAt":"2026-09-18 12:00:00"}\n';
    } else if (trimmed.startsWith('docker ps')) {
      stdout = 'CONTAINER ID   IMAGE                 COMMAND                  CREATED        STATUS                    PORTS                    NAMES\n'
          'e7a8f192b0c1   nginx:alpine          "/docker-entrypoint.…"   2 days ago     Up 2 days                 0.0.0.0:80->80/tcp       nginx_proxy\n'
          '4b1c8f309d2a   postgres:16-alpine    "docker-entrypoint.s…"   5 days ago     Up 5 days                 0.0.0.0:5432->5432/tcp   postgres\n'
          '98f23a100ce4   app/api-gateway:1.0   "/entrypoint.sh"         3 hours ago    Restarting (1) 20s ago                             api_gateway_service\n'
          '109bcfa37e21   redis:7-alpine        "docker-entrypoint.s…"   2 weeks ago    Up 2 weeks                0.0.0.0:6379->6379/tcp   redis\n';
    } else if (trimmed.startsWith('docker stats')) {
      stdout = 'CONTAINER ID   NAME                       CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O\n'
          'e7a8f192b0c1   nginx_proxy                0.15%     35.4MiB / 7.8GiB      0.44%     124MB / 89MB      1.2MB / 0B\n'
          '4b1c8f309d2a   postgres                   1.82%     580MiB / 7.8GiB       7.25%     450MB / 1.1GB     45MB / 120MB\n'
          '98f23a100ce4   api_gateway_service        12.4%     1.2GiB / 7.8GiB       15.3%     32MB / 15MB       80MB / 10MB\n'
          '109bcfa37e21   redis                      0.08%     42.1MiB / 7.8GiB      0.53%     80MB / 65MB       5MB / 2MB\n';
    } else if (trimmed.startsWith('docker system df')) {
      stdout = 'TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE\n'
          'Images          14        4         4.21GB    2.15GB (51%)\n'
          'Containers      4         3         12.5MB    0B (0%)\n'
          'Local Volumes   6         3         1.85GB    540MB (29%)\n'
          'Build Cache     0         0         0B        0B\n';
    } else if (trimmed.startsWith('ss -lntp')) {
      stdout = 'State      Recv-Q Send-Q Local Address:Port               Peer Address:Port              \n'
          'LISTEN     0      128    0.0.0.0:22                      0.0.0.0:*                      \n'
          'LISTEN     0      511    0.0.0.0:80                      0.0.0.0:*                      \n'
          'LISTEN     0      511    0.0.0.0:443                     0.0.0.0:*                      \n'
          'LISTEN     0      128    0.0.0.0:5432                    0.0.0.0:*                      \n'
          'LISTEN     0      511    0.0.0.0:6379                    0.0.0.0:*                      \n';
    } else if (trimmed.startsWith('ps aux --sort=-%cpu')) {
      stdout = 'USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND\n'
          'cas         1240 14.2 15.3 1248000 121000 ?      Sl   06:15   2:40 python3 /app/service.py\n'
          'postgres     890  2.1  7.2  890000 590000 ?      Ss   Sep27  45:10 postgres: main\n'
          'nginx        540  0.5  0.4   35000  36000 ?      S    Sep30   1:12 nginx: worker process\n';
    } else if (trimmed.startsWith('ps aux --sort=-%mem')) {
      stdout = 'USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND\n'
          'cas         1240 14.2 15.3 1248000 121000 ?      Sl   06:15   2:40 python3 /app/service.py\n'
          'postgres     890  2.1  7.2  890000 590000 ?      Ss   Sep27  45:10 postgres: main\n'
          'redis        420  0.1  0.5   54000  43000 ?      Ssl  Sep18   5:20 redis-server *:6379\n';
    } else if (trimmed.contains('restart')) {
      stdout = 'api_gateway_service\n';
    } else if (trimmed.contains('docker logs')) {
      stdout = '2026-10-02T09:20:01.120Z [INFO] Service starting up on port 8080...\n'
          '2026-10-02T09:20:02.450Z [INFO] Connecting to database postgres://cas:***@postgres:5432/app_db\n'
          '2026-10-02T09:20:05.110Z [ERROR] Failed to establish DB connection: timeout after 3000ms\n'
          '2026-10-02T09:20:05.115Z [WARNING] Retrying in 5 seconds...\n'
          '2026-10-02T09:20:10.120Z [CRITICAL] Exception in worker: ConnectionRefusedError\n';
    } else {
      stdout = 'Command executed successfully in mock environment.\nOutput of: $trimmed\n';
    }

    final finishedAt = DateTime.now();
    return CommandResult(
      stdout: stdout,
      stderr: stderr,
      exitCode: exitCode,
      startedAt: startedAt,
      finishedAt: finishedAt,
      duration: finishedAt.difference(startedAt),
    );
  }

  @override
  Future<InteractiveShell> openShell(
    ServerConfig server, {
    int width = 80,
    int height = 24,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockInteractiveShell(server);
  }

  @override
  Future<Stream<String>> streamLogs(
    ServerConfig server,
    String containerName, {
    int tail = 100,
    bool timestamps = true,
  }) async {
    final controller = StreamController<String>();
    int count = 0;

    // Send historical logs
    final initialLogs = [
      '2026-10-02T09:15:00.001Z [INFO] App initialized version 1.9.4',
      '2026-10-02T09:15:01.050Z [INFO] Connected to Redis cache at redis:6379',
      '2026-10-02T09:15:02.120Z [INFO] Listening for webhook events from API Service',
      '2026-10-02T09:16:15.890Z [WARN] Slow query detected on /api/v1/sync_inventory (duration: 1240ms)',
      '2026-10-02T09:18:22.330Z [ERROR] Upstream timeout on endpoint /web/dataset/call_kw',
      '2026-10-02T09:18:25.000Z [INFO] Auto-reconnecting database worker pool...',
    ];

    for (final l in initialLogs) {
      controller.add(l);
    }

    // Stream new log lines every 2 seconds
    final timer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (controller.isClosed) {
        t.cancel();
        return;
      }
      count++;
      controller.add('${DateTime.now().toUtc().toIso8601String()} [INFO] Worker health ping heartbeat #$count (OK)');
    });

    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> disconnect(String serverId) async {}
}
