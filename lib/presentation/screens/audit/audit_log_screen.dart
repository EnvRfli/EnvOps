import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/security/command_risk_analyzer.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/audit_providers.dart';
import '../../widgets/env_badge.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _searchFilter = '';

  Color _getRiskColor(CommandRisk risk) {
    switch (risk) {
      case CommandRisk.readOnly:
        return AppTheme.statusGreen;
      case CommandRisk.serviceChange:
        return AppTheme.statusYellow;
      case CommandRisk.destructive:
        return AppTheme.statusRed;
    }
  }

  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Command History?'),
        content: const Text('Are you sure you want to clear the command audit logs? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(auditLogProvider.notifier).clearAll();
            },
            child: const Text('CLEAR LOGS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auditLogsAsync = ref.watch(auditLogProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Command Activity Audit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 22),
            tooltip: 'Clear History',
            onPressed: _confirmClearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Filter by command, server, or status...',
                prefixIcon: Icon(Icons.filter_list, size: 18),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchFilter = val.toLowerCase()),
            ),
          ),

          Expanded(
            child: auditLogsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
              error: (e, _) => Center(child: Text('Error loading audit log: $e')),
              data: (logs) {
                final filtered = logs.where((l) {
                  if (_searchFilter.isEmpty) return true;
                  return l.commandText.toLowerCase().contains(_searchFilter) ||
                      l.serverName.toLowerCase().contains(_searchFilter) ||
                      l.environment.label.toLowerCase().contains(_searchFilter);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No command executions recorded yet.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final log = filtered[idx];
                    final timeStr = DateFormat('MM-dd HH:mm:ss').format(log.timestamp);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      timeStr,
                                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      log.serverName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                EnvBadge(environment: log.environment, isDense: true),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.commandText,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _getRiskColor(log.risk).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: _getRiskColor(log.risk)),
                                      ),
                                      child: Text(
                                        log.risk == CommandRisk.readOnly
                                            ? 'READ ONLY'
                                            : (log.risk == CommandRisk.serviceChange ? 'SERVICE CHANGE' : 'DESTRUCTIVE'),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _getRiskColor(log.risk),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${log.durationMs}ms',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                                Text(
                                  log.isSuccess ? 'Exit 0' : 'Exit ${log.exitCode}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: log.isSuccess ? AppTheme.statusGreen : AppTheme.statusRed,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
