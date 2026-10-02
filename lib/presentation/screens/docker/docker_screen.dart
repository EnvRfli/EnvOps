import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/command_risk_analyzer.dart';
import '../../../core/utils/shell_escaper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/audit_log.dart';
import '../../../domain/models/docker_container.dart';
import '../../../domain/models/server_config.dart';
import '../../providers/audit_providers.dart';
import '../../providers/server_providers.dart';
import '../../providers/storage_providers.dart';
import '../diagnostics/command_output_dialog.dart';
import 'docker_logs_screen.dart';
import 'restart_confirmation_dialog.dart';

class DockerScreen extends ConsumerStatefulWidget {
  final ServerConfig server;

  const DockerScreen({super.key, required this.server});

  @override
  ConsumerState<DockerScreen> createState() => _DockerScreenState();
}

class _DockerScreenState extends ConsumerState<DockerScreen> {
  String _searchQuery = '';

  Future<void> _refresh() async {
    ref.invalidate(serverContainersProvider(widget.server));
  }

  void _showContainerDetails(DockerContainer container) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusDot(container),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    container.primaryName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Text(
                  container.state.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(container),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Container ID', container.id.isNotEmpty ? container.id.substring(0, 12.clamp(0, container.id.length)) : 'N/A'),
            _infoRow('Image', container.image),
            _infoRow('Status', container.status),
            if (container.ports.isNotEmpty) _infoRow('Ports', container.ports),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 8),

            // Actions Grid
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text('Logs'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DockerLogsScreen(
                            server: widget.server,
                            containerName: container.primaryName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.query_stats, size: 16),
                    label: const Text('Stats'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _runContainerStats(container.primaryName);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Restart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.server.isProduction ? AppTheme.envProd : AppTheme.envStaging,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _confirmRestart(container.primaryName);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runContainerStats(String containerName) async {
    final cleanName = ShellEscaper.sanitizeContainerName(containerName);
    final ssh = ref.read(sshRepositoryProvider);
    final cmd = 'docker stats --no-stream $cleanName';

    try {
      final res = await ssh.execute(widget.server, cmd);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => CommandOutputDialog(
            server: widget.server,
            commandTitle: 'Stats for $cleanName',
            commandText: cmd,
            result: res,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get stats: $e'), backgroundColor: AppTheme.statusRed),
        );
      }
    }
  }

  Future<void> _confirmRestart(String containerName) async {
    final cleanName = ShellEscaper.sanitizeContainerName(containerName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => RestartConfirmationDialog(
        server: widget.server,
        targetName: cleanName,
        actionDescription: 'Restart Container',
      ),
    );

    if (confirmed == true) {
      _executeRestart(cleanName);
    }
  }

  Future<void> _executeRestart(String cleanName) async {
    final ssh = ref.read(sshRepositoryProvider);
    final cmd = 'docker restart $cleanName';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restarting container $cleanName...'),
        backgroundColor: AppTheme.envStaging,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final res = await ssh.execute(widget.server, cmd, timeout: const Duration(seconds: 30));

      // Record in audit log
      ref.read(auditLogProvider.notifier).recordLog(
            AuditLogEntry(
              id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
              timestamp: DateTime.now(),
              serverId: widget.server.id,
              serverName: widget.server.name,
              environment: widget.server.environment,
              commandText: cmd,
              risk: CommandRisk.serviceChange,
              exitCode: res.exitCode,
              durationMs: res.duration.inMilliseconds,
              isSuccess: res.isSuccess,
            ),
          );

      if (mounted) {
        if (res.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Container $cleanName restarted successfully!'),
              backgroundColor: AppTheme.statusGreen,
            ),
          );
          _refresh();
        } else {
          showDialog(
            context: context,
            builder: (_) => CommandOutputDialog(
              server: widget.server,
              commandTitle: 'Restart Failed: $cleanName',
              commandText: cmd,
              result: res,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restart error: $e'), backgroundColor: AppTheme.statusRed),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DockerContainer c) {
    if (c.isRestarting) return AppTheme.statusRed;
    if (c.isRunning) return AppTheme.statusGreen;
    return AppTheme.statusGray;
  }

  Widget _buildStatusDot(DockerContainer c) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getStatusColor(c),
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containersAsync = ref.watch(serverContainersProvider(widget.server));

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Docker Containers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('${widget.server.name} (${widget.server.environment.label})',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Containers',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search container name or image...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // Containers List
          Expanded(
            child: containersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.statusRed, size: 40),
                      const SizedBox(height: 8),
                      Text('Error loading containers: $err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
              data: (containers) {
                final filtered = containers.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  return c.names.toLowerCase().contains(_searchQuery) ||
                      c.image.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No containers found',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final c = filtered[idx];
                      return Card(
                        child: ListTile(
                          onTap: () => _showContainerDetails(c),
                          leading: _buildStatusDot(c),
                          title: Text(
                            c.primaryName,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.isRestarting ? AppTheme.statusRed : const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                c.image,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
