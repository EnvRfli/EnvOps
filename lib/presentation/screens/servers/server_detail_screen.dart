import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/http_health_service.dart';
import '../../../domain/models/audit_log.dart';
import '../../../domain/models/ops_command.dart';
import '../../../domain/models/server_config.dart';
import '../../../domain/models/server_health.dart';
import '../../providers/audit_providers.dart';
import '../../providers/server_providers.dart';
import '../../providers/storage_providers.dart';
import '../../widgets/connection_status_badge.dart';
import '../../widgets/env_badge.dart';
import '../diagnostics/command_output_dialog.dart';
import '../diagnostics/full_diagnose_screen.dart';
import '../docker/docker_screen.dart';
import '../terminal/interactive_terminal_screen.dart';
import 'add_edit_server_screen.dart';

class ServerDetailScreen extends ConsumerStatefulWidget {
  final ServerConfig server;

  const ServerDetailScreen({super.key, required this.server});

  @override
  ConsumerState<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends ConsumerState<ServerDetailScreen> {
  bool _isLoadingHealth = false;
  ServerHealth? _health;
  List<HttpHealthResult> _httpHealthResults = [];
  ServerConnectionStatus _connectionStatus = ServerConnectionStatus.unknown;
  String? _lastSshError;

  ServerConfig _getActiveServer() {
    final list = ref.read(serverListProvider).asData?.value;
    if (list != null) {
      final match = list.where((s) => s.id == widget.server.id).firstOrNull;
      if (match != null) return match;
    }
    return widget.server;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshMetrics();
      }
    });
  }

  void _setConnectionStatus(String serverId, ServerConnectionStatus status) {
    if (!mounted) return;
    setState(() => _connectionStatus = status);
    Future.microtask(() {
      if (mounted) {
        ref.read(serverConnectionStateProvider.notifier).setStatus(serverId, status);
      }
    });
  }

  Future<void> _refreshMetrics() async {
    final server = _getActiveServer();
    if (!mounted) return;
    setState(() => _isLoadingHealth = true);
    final ssh = ref.read(sshRepositoryProvider);

    // 1. Check SSH status
    try {
      _setConnectionStatus(server.id, ServerConnectionStatus.connecting);
      await ssh.testConnection(server);
      if (mounted) {
        setState(() => _lastSshError = null);
        _setConnectionStatus(server.id, ServerConnectionStatus.connected);
      }
    } catch (e) {
      debugPrint('SSH testConnection failed for ${server.name}: $e');
      if (mounted) {
        setState(() => _lastSshError = e.toString());
        _setConnectionStatus(server.id, ServerConnectionStatus.error);
        setState(() => _isLoadingHealth = false);
      }
      return;
    }

    // 2. Fetch system health metrics in ONE single batched SSH call
    // This reduces round-trips from 4 down to 1, avoiding mobile network latency and lag.
    try {
      const sep = '___CAS_SEP___';
      const batchCmd =
          'uptime && echo "$sep" && free -h && echo "$sep" && df -h / | tail -1 && echo "$sep" && '
          'DK="docker"; if ! docker ps >/dev/null 2>&1 && sudo -n docker ps >/dev/null 2>&1; then DK="sudo -n docker"; fi; '
          r'($DK ps -q 2>/dev/null | wc -l && $DK ps -f status=restarting -q 2>/dev/null | wc -l && $DK ps -f health=unhealthy -q 2>/dev/null | wc -l || echo -e "0\n0\n0")';

      final res = await ssh.execute(server, batchCmd, timeout: const Duration(seconds: 10));
      final parts = res.stdout.split(sep);

      final uptimeText = parts.isNotEmpty ? parts[0].trim() : '';
      final memText = parts.length > 1 ? parts[1].trim() : '';
      final diskText = parts.length > 2 ? parts[2].trim() : '';
      final dockerText = parts.length > 3 ? parts[3].trim() : '';

      int dockerRunning = 0;
      int dockerRestarting = 0;
      int dockerUnhealthy = 0;
      bool dockerAvail = true;

      final dockerLines = dockerText.split('\n');
      if (dockerLines.length >= 3) {
        dockerRunning = int.tryParse(dockerLines[0].trim()) ?? 0;
        dockerRestarting = int.tryParse(dockerLines[1].trim()) ?? 0;
        dockerUnhealthy = int.tryParse(dockerLines[2].trim()) ?? 0;
      } else {
        dockerAvail = false;
      }

      final diskParts = diskText.split(RegExp(r'\s+'));
      final diskPct = diskParts.length >= 5 ? diskParts[4] : '';

      if (mounted) {
        setState(() {
          _health = ServerHealth(
            uptime: uptimeText,
            loadAvg: _extractLoad(uptimeText),
            memorySummary: memText,
            diskSummary: diskText,
            diskUsedPercent: diskPct,
            dockerRunning: dockerRunning,
            dockerRestarting: dockerRestarting,
            dockerUnhealthy: dockerUnhealthy,
            dockerAvailable: dockerAvail,
            checkedAt: DateTime.now(),
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching system health metrics: $e');
    }

    // 3. Check HTTP Endpoints if configured
    if (server.profile.healthEndpoints.isNotEmpty) {
      final httpService = ref.read(httpHealthServiceProvider);
      final results = await httpService.checkAll(
        server.profile.healthEndpoints,
      );
      if (mounted) {
        setState(() => _httpHealthResults = results);
      }
    }

    if (mounted) setState(() => _isLoadingHealth = false);
  }

  String _extractLoad(String text) {
    final idx = text.indexOf('load average:');
    if (idx != -1) return text.substring(idx + 13).trim();
    return '';
  }

  Future<void> _executeCommand(OpsCommand cmd) async {
    final server = _getActiveServer();
    final ssh = ref.read(sshRepositoryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Executing "${cmd.name}"...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final res = await ssh.execute(server, cmd.command, timeout: cmd.timeout);

      // Record in audit log
      ref
          .read(auditLogProvider.notifier)
          .recordLog(
            AuditLogEntry(
              id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
              timestamp: DateTime.now(),
              serverId: server.id,
              serverName: server.name,
              environment: server.environment,
              commandText: cmd.command,
              risk: cmd.risk,
              exitCode: res.exitCode,
              durationMs: res.duration.inMilliseconds,
              isSuccess: res.isSuccess,
            ),
          );

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => CommandOutputDialog(
            server: server,
            commandTitle: cmd.name,
            commandText: cmd.command,
            result: res,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Execution error: $e'),
            backgroundColor: AppTheme.statusRed,
          ),
        );
      }
    }
  }

  void _confirmDeleteServer(BuildContext context) {
    final server = _getActiveServer();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Server?'),
        content: Text(
          'Are you sure you want to delete "${server.name}"? This removes it from your dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRed,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(serverListProvider.notifier)
                  .deleteServer(server.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Server "${server.name}" deleted.'),
                    backgroundColor: AppTheme.statusGreen,
                  ),
                );
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serversAsync = ref.watch(serverListProvider);
    final server = serversAsync.maybeWhen(
      data: (list) =>
          list.where((s) => s.id == widget.server.id).firstOrNull ??
          widget.server,
      orElse: () => widget.server,
    );

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              server.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${server.username}@${server.hostname}:${server.port}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Server',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditServerScreen(existingServer: server),
                ),
              );
              if (mounted) {
                _refreshMetrics();
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppTheme.statusRed,
            ),
            tooltip: 'Delete Server',
            onPressed: () => _confirmDeleteServer(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Status',
            onPressed: _refreshMetrics,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMetrics,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Status & Environment Bar
            _buildStatusBar(server),
            const SizedBox(height: 12),

            // HTTP Health Checks if configured (Section 24)
            if (_httpHealthResults.isNotEmpty) ...[
              _buildHttpHealthCard(),
              const SizedBox(height: 12),
            ],

            // System Health Metrics Card
            _buildSystemHealthCard(),
            const SizedBox(height: 12),

            // Docker Summary Card
            _buildDockerSummaryCard(server),
            const SizedBox(height: 16),

            // Open Terminal Hero Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.terminal, size: 20),
                label: const Text(
                  'OPEN INTERACTIVE SSH TERMINAL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: server.isProduction
                      ? const Color(0xFF991B1B)
                      : AppTheme.primaryBlueDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InteractiveTerminalScreen(server: server),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Quick Diagnostic Actions Grid (Section 12, 13)
            _buildQuickDiagnosticsSection(server),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(ServerConfig server) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              EnvBadge(environment: server.environment),
              InkWell(
                onTap:
                    _connectionStatus == ServerConnectionStatus.error &&
                        _lastSshError != null
                    ? () => _showSshErrorDialog(server)
                    : _refreshMetrics,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'SSH: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      ConnectionStatusBadge(status: _connectionStatus),
                      if (_connectionStatus ==
                          ServerConnectionStatus.error) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline,
                          size: 13,
                          color: AppTheme.statusRed,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_connectionStatus == ServerConnectionStatus.error &&
            _lastSshError != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showSshErrorDialog(server),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF450A0A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.statusRed.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppTheme.statusRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SSH Error: ${_friendlyErrorMessage(_lastSshError!)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFCA5A5),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFFFCA5A5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _friendlyErrorMessage(String err) {
    if (err.contains('HostKeyMismatchFailure')) {
      return 'Host key fingerprint mismatch. Server identity has changed.';
    }
    if (err.contains('AuthenticationFailure')) {
      return 'Authentication failed. Check private key passphrase & server authorized_keys.';
    }
    if (err.contains('HostUnreachableFailure') ||
        err.contains('SocketException')) {
      return 'Host unreachable. Check IP, network, or Tailscale status.';
    }
    if (err.contains('ConnectionTimeoutFailure') ||
        err.contains('TimeoutException')) {
      return 'Connection timed out. Server or port 22 not responding.';
    }
    return err;
  }

  void _showSshErrorDialog(ServerConfig server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.statusRed),
            SizedBox(width: 8),
            Text('SSH Connection Error', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not connect to ${server.username}@${server.hostname}:${server.port}:',
              style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SelectableText(
                _lastSshError ?? 'Unknown error',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFFCA5A5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('DISMISS'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('RETRY'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _refreshMetrics();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHttpHealthCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HTTP HEALTH CHECKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(height: 8),
            for (final res in _httpHealthResults)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      res.isHealthy ? Icons.check_circle : Icons.error,
                      size: 14,
                      color: res.isHealthy
                          ? AppTheme.statusGreen
                          : AppTheme.statusRed,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        res.summary,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: res.isHealthy
                              ? Colors.white
                              : const Color(0xFFFCA5A5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SYSTEM HEALTH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                if (_isLoadingHealth)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_health != null)
                  Text(
                    'Checked ${_health!.checkedAt.hour.toString().padLeft(2, '0')}:${_health!.checkedAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _metricBox(
                    'LOAD AVG',
                    _health?.loadAvg.isNotEmpty == true
                        ? _health!.loadAvg
                        : '...',
                    Icons.speed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricBox(
                    'DISK ROOT',
                    _health?.diskUsedPercent.isNotEmpty == true
                        ? _health!.diskUsedPercent
                        : '...',
                    Icons.storage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_health?.uptime.isNotEmpty == true)
              Text(
                'Uptime: ${_health!.uptime.split(',').first}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockerSummaryCard(ServerConfig server) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DockerScreen(server: server)),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.view_in_ar,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'DOCKER STATUS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _dockerCountChip(
                    'Running',
                    _health?.dockerRunning.toString() ?? '...',
                    AppTheme.statusGreen,
                  ),
                  _dockerCountChip(
                    'Restarting',
                    _health?.dockerRestarting.toString() ?? '...',
                    AppTheme.statusRed,
                  ),
                  _dockerCountChip(
                    'Unhealthy',
                    _health?.dockerUnhealthy.toString() ?? '...',
                    AppTheme.statusYellow,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dockerCountChip(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildQuickDiagnosticsSection(ServerConfig server) {
    final builtInCommands = OpsCommand.defaultBuiltInCommands;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'QUICK DIAGNOSTICS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.playlist_play, size: 16),
              label: const Text(
                'FULL DIAGNOSE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FullDiagnoseScreen(server: server),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: builtInCommands.map((cmd) {
            return ActionChip(
              backgroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: Color(0xFF334155)),
              label: Text(
                cmd.name,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              onPressed: () => _executeCommand(cmd),
            );
          }).toList(),
        ),
      ],
    );
  }
}
