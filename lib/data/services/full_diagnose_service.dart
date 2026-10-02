import '../../core/security/secret_redactor.dart';
import '../../domain/models/docker_container.dart';
import '../../domain/models/server_config.dart';
import '../../domain/models/server_health.dart';
import '../../domain/repositories/ssh_repository.dart';

class DiagnoseResultSection {
  final String title;
  final String content;
  final bool isAvailable;

  const DiagnoseResultSection({
    required this.title,
    required this.content,
    this.isAvailable = true,
  });
}

class FullDiagnoseReport {
  final ServerConfig server;
  final DateTime timestamp;
  final List<DiagnoseResultSection> sections;
  final ServerHealth healthSummary;

  const FullDiagnoseReport({
    required this.server,
    required this.timestamp,
    required this.sections,
    required this.healthSummary,
  });

  /// Standard Human-Readable Diagnostic Text (for Copy All / Share)
  String toStandardText() {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('ENVOPS SYSTEM DIAGNOSTIC REPORT');
    buffer.writeln('========================================');
    buffer.writeln('Server     : ${server.name}');
    buffer.writeln('Environment: ${server.environment.label}');
    buffer.writeln('Host       : ${server.hostname}:${server.port}');
    buffer.writeln('User       : ${server.username}');
    buffer.writeln('Time (UTC) : ${timestamp.toUtc().toIso8601String()}');
    buffer.writeln('----------------------------------------');

    for (final section in sections) {
      buffer.writeln('\n[ ${section.title.toUpperCase()} ]');
      buffer.writeln(section.content.trim());
    }

    buffer.writeln('\n========================================');
    buffer.writeln('END OF REPORT');
    buffer.writeln('========================================');
    return buffer.toString();
  }

  /// AI-Optimized Report (Redacted & specifically instructed for ChatGPT / Claude)
  String toAiPromptText({String? problemDescription}) {
    final buffer = StringBuffer();
    buffer.writeln('ENVOPS INCIDENT REPORT');
    buffer.writeln('=======================');
    buffer.writeln('Server     : ${server.name}');
    buffer.writeln('Environment: ${server.environment.label}');
    buffer.writeln('Host       : ${server.hostname}');
    buffer.writeln('Report Time: ${timestamp.toUtc().toIso8601String()}');
    buffer.writeln('Problem    : ${problemDescription?.trim().isNotEmpty == true ? problemDescription : "General system health inspection / troubleshooting"}');
    buffer.writeln();
    buffer.writeln('=== REDACTED DIAGNOSTIC SNAPSHOT ===');

    for (final section in sections) {
      buffer.writeln('\n--- ${section.title} ---');
      final redactedContent = SecretRedactor.redact(section.content.trim());
      buffer.writeln(redactedContent);
    }

    buffer.writeln();
    buffer.writeln('=== AI ANALYSIS REQUEST ===');
    buffer.writeln('1. Analyze the system metrics, Docker containers, ports, and errors above.');
    buffer.writeln('2. Identify any bottlenecks, resource exhaustion, crashed containers, or anomalies.');
    buffer.writeln('3. Start with READ-ONLY diagnostic commands to gather more details.');
    buffer.writeln('4. Do NOT propose destructive commands (e.g., rm, drop, volume rm) unless strictly necessary.');
    buffer.writeln('5. Clearly explain the purpose and risk of every suggested state-changing command.');
    buffer.writeln();
    buffer.writeln(SecretRedactor.disclaimer);

    return buffer.toString();
  }
}

class FullDiagnoseService {
  final SshRepository _ssh;

  FullDiagnoseService(this._ssh);

  Future<FullDiagnoseReport> runDiagnosis(
    ServerConfig server, {
    void Function(String stepName)? onProgress,
  }) async {
    final sections = <DiagnoseResultSection>[];
    final now = DateTime.now();

    // 1. Hostname & Uptime
    onProgress?.call('Checking system uptime and load...');
    String uptimeOut = '';
    try {
      final res = await _ssh.execute(server, 'hostname && date -u && uptime');
      uptimeOut = res.stdout.trim();
      sections.add(DiagnoseResultSection(title: 'System Uptime & Load', content: uptimeOut));
    } catch (e) {
      sections.add(DiagnoseResultSection(title: 'System Uptime & Load', content: 'Failed: $e', isAvailable: false));
    }

    // 2. Memory Usage
    onProgress?.call('Checking memory usage (free -h)...');
    String memOut = '';
    try {
      final res = await _ssh.execute(server, 'free -h');
      memOut = res.stdout.trim();
      sections.add(DiagnoseResultSection(title: 'Memory Usage', content: memOut));
    } catch (e) {
      sections.add(DiagnoseResultSection(title: 'Memory Usage', content: 'Failed: $e', isAvailable: false));
    }

    // 3. Disk Space & Inodes
    onProgress?.call('Checking disk space (df -h)...');
    String diskOut = '';
    try {
      final res = await _ssh.execute(server, 'df -h -x tmpfs -x devtmpfs && echo "--- Inodes ---" && df -i -x tmpfs -x devtmpfs');
      diskOut = res.stdout.trim();
      sections.add(DiagnoseResultSection(title: 'Disk Space & Inodes', content: diskOut));
    } catch (e) {
      sections.add(DiagnoseResultSection(title: 'Disk Space & Inodes', content: 'Failed: $e', isAvailable: false));
    }

    // 4. Docker Containers
    onProgress?.call('Checking Docker container status...');
    int dockerRunning = 0;
    int dockerRestarting = 0;
    int dockerUnhealthy = 0;
    int dockerTotal = 0;
    bool dockerAvailable = true;

    try {
      final res = await _ssh.execute(
        server,
        'docker ps -a --format \'{"ID":"{{.ID}}","Names":"{{.Names}}","Image":"{{.Image}}","State":"{{.State}}","Status":"{{.Status}}","Ports":"{{.Ports}}"}\'',
      );

      if (res.exitCode != 0 || res.stdout.trim().isEmpty) {
        // Fallback to plain docker ps
        final fallback = await _ssh.execute(server, 'docker ps -a');
        if (fallback.exitCode == 0 && fallback.stdout.trim().isNotEmpty) {
          final containers = DockerContainer.parseTableOutput(fallback.stdout);
          dockerTotal = containers.length;
          dockerRunning = containers.where((c) => c.isRunning).length;
          dockerRestarting = containers.where((c) => c.isRestarting).length;
          dockerUnhealthy = containers.where((c) => c.isUnhealthy).length;
          sections.add(DiagnoseResultSection(title: 'Docker Containers', content: fallback.stdout.trim()));
        } else {
          dockerAvailable = false;
          sections.add(const DiagnoseResultSection(title: 'Docker Containers', content: 'Docker not running or not installed on server.', isAvailable: false));
        }
      } else {
        final containers = DockerContainer.parseJsonLines(res.stdout);
        dockerTotal = containers.length;
        dockerRunning = containers.where((c) => c.isRunning).length;
        dockerRestarting = containers.where((c) => c.isRestarting).length;
        dockerUnhealthy = containers.where((c) => c.isUnhealthy).length;

        final summaryLines = containers.map((c) {
          final stateTag = c.isRestarting
              ? '[RESTARTING]'
              : (c.isRunning ? '[RUNNING]' : '[STOPPED]');
          return '$stateTag ${c.primaryName.padRight(28)} | ${c.status} | ${c.image}';
        }).join('\n');

        sections.add(DiagnoseResultSection(title: 'Docker Containers', content: summaryLines.isNotEmpty ? summaryLines : 'No containers found.'));
      }
    } catch (e) {
      dockerAvailable = false;
      sections.add(DiagnoseResultSection(title: 'Docker Containers', content: 'Docker check failed or not installed: $e', isAvailable: false));
    }

    // 5. Docker Stats
    if (dockerAvailable) {
      onProgress?.call('Sampling Docker stats...');
      try {
        final res = await _ssh.execute(server, 'docker stats --no-stream');
        if (res.exitCode == 0) {
          sections.add(DiagnoseResultSection(title: 'Docker Resource Stats', content: res.stdout.trim()));
        }
      } catch (_) {}
    }

    // 6. Listening Ports
    onProgress?.call('Checking open network ports (ss -lntp)...');
    try {
      final res = await _ssh.execute(server, 'ss -lntp 2>/dev/null || netstat -tuln 2>/dev/null');
      sections.add(DiagnoseResultSection(title: 'Open Listening Ports', content: res.stdout.trim()));
    } catch (e) {
      sections.add(DiagnoseResultSection(title: 'Open Listening Ports', content: 'Failed: $e', isAvailable: false));
    }

    // 7. Top CPU & Memory Processes
    onProgress?.call('Inspecting top processes...');
    try {
      final res = await _ssh.execute(server, 'ps aux --sort=-%cpu | head -12');
      sections.add(DiagnoseResultSection(title: 'Top CPU Processes', content: res.stdout.trim()));
    } catch (_) {}

    try {
      final res = await _ssh.execute(server, 'ps aux --sort=-%mem | head -12');
      sections.add(DiagnoseResultSection(title: 'Top Memory Processes', content: res.stdout.trim()));
    } catch (_) {}

    // 8. Recent Errors in Logs
    onProgress?.call('Scanning recent system error logs...');
    try {
      final res = await _ssh.execute(server, 'journalctl -p 3 -xb -n 25 --no-pager 2>/dev/null || dmesg -T -l err 2>/dev/null | tail -25');
      if (res.stdout.trim().isNotEmpty) {
        sections.add(DiagnoseResultSection(title: 'Recent System Errors', content: res.stdout.trim()));
      }
    } catch (_) {}

    // Parse summary health
    final healthSummary = ServerHealth(
      hostname: uptimeOut.split('\n').firstOrNull ?? server.hostname,
      uptime: uptimeOut,
      loadAvg: _extractLoad(uptimeOut),
      memorySummary: memOut,
      diskSummary: diskOut,
      dockerRunning: dockerRunning,
      dockerRestarting: dockerRestarting,
      dockerUnhealthy: dockerUnhealthy,
      dockerTotal: dockerTotal,
      dockerAvailable: dockerAvailable,
      checkedAt: now,
    );

    return FullDiagnoseReport(
      server: server,
      timestamp: now,
      sections: sections,
      healthSummary: healthSummary,
    );
  }

  String _extractLoad(String uptimeText) {
    final idx = uptimeText.indexOf('load average:');
    if (idx != -1) {
      return uptimeText.substring(idx + 13).trim();
    }
    return '';
  }
}
