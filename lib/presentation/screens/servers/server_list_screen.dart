import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/server_config.dart';
import '../../providers/server_providers.dart';
import '../../widgets/connection_status_badge.dart';
import '../../widgets/env_badge.dart';
import 'add_edit_server_screen.dart';
import 'server_detail_screen.dart';

class ServerListScreen extends ConsumerStatefulWidget {
  const ServerListScreen({super.key});

  @override
  ConsumerState<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends ConsumerState<ServerListScreen> {
  String _searchQuery = '';
  ServerEnvironment? _envFilter;

  @override
  Widget build(BuildContext context) {
    final serversAsync = ref.watch(serverListProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/envops_logo.png', height: 26, width: 26),
            const SizedBox(width: 10),
            const Text('ENVOPS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            const Spacer(),
            serversAsync.maybeWhen(
              data: (servers) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  '${servers.length} servers',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                ),
              ),
              orElse: () => const SizedBox(),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search server name, IP, tag, environment...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
                const SizedBox(height: 8),
                // Environment filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('ALL', null),
                      for (final env in ServerEnvironment.values)
                        _filterChip(env.label, env),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Server List
          Expanded(
            child: serversAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
              error: (err, _) => Center(child: Text('Error loading servers: $err')),
              data: (servers) {
                final filtered = servers.where((s) {
                  if (_envFilter != null && s.environment != _envFilter) return false;
                  if (_searchQuery.isEmpty) return true;
                  final matchName = s.name.toLowerCase().contains(_searchQuery);
                  final matchHost = s.hostname.toLowerCase().contains(_searchQuery);
                  final matchEnv = s.environment.label.toLowerCase().contains(_searchQuery);
                  final matchTags = s.tags.any((t) => t.toLowerCase().contains(_searchQuery));
                  return matchName || matchHost || matchEnv || matchTags;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(servers.isEmpty);
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(serverListProvider.notifier).loadServers(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final server = filtered[idx];
                      return _buildServerCard(server);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlueDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Server', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditServerScreen()),
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, ServerEnvironment? env) {
    final isSelected = _envFilter == env;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white70)),
        selected: isSelected,
        selectedColor: AppTheme.primaryBlue,
        backgroundColor: const Color(0xFF1E293B),
        side: BorderSide(color: isSelected ? AppTheme.primaryBlue : const Color(0xFF334155)),
        onSelected: (_) => setState(() => _envFilter = env),
      ),
    );
  }

  Widget _buildServerCard(ServerConfig server) {
    final connectionStatuses = ref.watch(serverConnectionStateProvider);
    final status = connectionStatuses[server.id] ?? ServerConnectionStatus.unknown;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ServerDetailScreen(server: server)),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Name & Environment Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      server.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                  ),
                  EnvBadge(environment: server.environment),
                ],
              ),
              const SizedBox(height: 6),

              // Host & Username
              Row(
                children: [
                  const Icon(Icons.lan_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    '${server.username}@${server.hostname}:${server.port}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),

              if (server.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  server.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],

              if (server.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: server.tags.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFF334155)),
              const SizedBox(height: 8),

              // Bottom status & Open button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ConnectionStatusBadge(status: status),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      backgroundColor: server.isProduction ? const Color(0xFF7F1D1D) : const Color(0xFF0369A1),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ServerDetailScreen(server: server)),
                      );
                    },
                    child: const Text('OPEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noServersTotal) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            Text(
              noServersTotal ? 'No Servers Configured' : 'No Matching Servers',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              noServersTotal
                  ? 'Add your Linux VPS servers to begin monitoring health, Docker containers, and opening secure SSH shells.'
                  : 'Try adjusting your search query or environment filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            if (noServersTotal) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add First Server'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddEditServerScreen()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
