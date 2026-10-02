import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/server_config.dart';
import '../../../domain/models/server_profile.dart';
import '../../providers/server_providers.dart';
import '../../providers/ssh_key_providers.dart';
import '../../providers/storage_providers.dart';
import '../../widgets/host_key_mismatch_dialog.dart';

class AddEditServerScreen extends ConsumerStatefulWidget {
  final ServerConfig? existingServer;

  const AddEditServerScreen({super.key, this.existingServer});

  @override
  ConsumerState<AddEditServerScreen> createState() => _AddEditServerScreenState();
}

class _AddEditServerScreenState extends ConsumerState<AddEditServerScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _userController;
  late final TextEditingController _descController;
  late final TextEditingController _fingerprintController;
  late final TextEditingController _tagsController;

  // Server Profile Controllers
  late final TextEditingController _nginxController;
  late final TextEditingController _redisController;
  late final TextEditingController _postgresController;
  late final TextEditingController _httpHealthNameController;
  late final TextEditingController _httpHealthUrlController;

  ServerEnvironment _environment = ServerEnvironment.production;
  String? _selectedKeyId;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existingServer;
    _nameController = TextEditingController(text: s?.name ?? '');
    _hostController = TextEditingController(text: s?.hostname ?? '');
    _portController = TextEditingController(text: s != null ? s.port.toString() : '22');
    _userController = TextEditingController(text: s?.username ?? 'root');
    _descController = TextEditingController(text: s?.description ?? '');
    _fingerprintController = TextEditingController(text: s?.hostKeyFingerprint ?? '');
    _tagsController = TextEditingController(text: s?.tags.join(', ') ?? '');

    _nginxController = TextEditingController(text: s?.profile.nginxContainer ?? '');
    _redisController = TextEditingController(text: s?.profile.redisContainer ?? '');
    _postgresController = TextEditingController(text: s?.profile.postgresContainer ?? '');
    _httpHealthNameController = TextEditingController(
      text: s?.profile.healthEndpoints.firstOrNull?.name ?? '',
    );
    _httpHealthUrlController = TextEditingController(
      text: s?.profile.healthEndpoints.firstOrNull?.url ?? '',
    );

    if (s != null) {
      _environment = s.environment;
      _selectedKeyId = s.keyId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _descController.dispose();
    _fingerprintController.dispose();
    _tagsController.dispose();
    _nginxController.dispose();
    _redisController.dispose();
    _postgresController.dispose();
    _httpHealthNameController.dispose();
    _httpHealthUrlController.dispose();
    super.dispose();
  }

  ServerConfig _buildCurrentConfig() {
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final healthEndpoints = <HttpHealthEndpoint>[];
    if (_httpHealthUrlController.text.trim().isNotEmpty) {
      healthEndpoints.add(
        HttpHealthEndpoint(
          id: 'ep_${DateTime.now().millisecondsSinceEpoch}',
          name: _httpHealthNameController.text.trim().isNotEmpty
              ? _httpHealthNameController.text.trim()
              : 'Primary API Health',
          url: _httpHealthUrlController.text.trim(),
        ),
      );
    }

    final profile = ServerProfile(
      nginxContainer: _nginxController.text.trim().isNotEmpty ? _nginxController.text.trim() : null,
      redisContainer: _redisController.text.trim().isNotEmpty ? _redisController.text.trim() : null,
      postgresContainer: _postgresController.text.trim().isNotEmpty ? _postgresController.text.trim() : null,
      healthEndpoints: healthEndpoints,
    );

    String hostname = _hostController.text.trim();
    int port = int.tryParse(_portController.text.trim()) ?? 22;

    // Handle case where user pasted "host:port" (e.g. 100.84.12.19:2222 or vps.example.com:22)
    if (hostname.contains(':') && !hostname.contains('::')) {
      final parts = hostname.split(':');
      if (parts.length == 2 && int.tryParse(parts[1]) != null) {
        hostname = parts[0].trim();
        port = int.parse(parts[1]);
      }
    }

    return ServerConfig(
      id: widget.existingServer?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      hostname: hostname,
      port: port,
      username: _userController.text.trim(),
      environment: _environment,
      description: _descController.text.trim(),
      hostKeyFingerprint: _fingerprintController.text.trim().isNotEmpty
          ? _fingerprintController.text.trim()
          : null,
      keyId: _selectedKeyId,
      profile: profile,
      tags: tags,
      createdAt: widget.existingServer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedKeyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an SSH key for authentication before testing.'),
          backgroundColor: AppTheme.statusRed,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
    });

    final server = _buildCurrentConfig();
    final ssh = ref.read(sshRepositoryProvider);

    try {
      final fingerprint = await ssh.testConnection(server);
      if (mounted) {
        setState(() {
          _isTesting = false;
          if (_fingerprintController.text.trim().isEmpty) {
            _fingerprintController.text = fingerprint;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection successful! Host key: $fingerprint'),
            backgroundColor: AppTheme.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTesting = false);
        if (e is HostKeyMismatchFailure) {
          showDialog(
            context: context,
            builder: (ctx) => HostKeyMismatchDialog(
              failure: e,
              onAbort: () {},
              onUpdateTrustedFingerprint: (newFp) {
                setState(() {
                  _fingerprintController.text = newFp;
                });
              },
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection failed: $e'),
              backgroundColor: AppTheme.statusRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) return;

    final server = _buildCurrentConfig();
    await ref.read(serverListProvider.notifier).saveServer(server);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server "${server.name}" saved!'),
          backgroundColor: AppTheme.statusGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keysAsync = ref.watch(sshKeyListProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(widget.existingServer != null ? 'Edit Server' : 'Add Server'),
        actions: [
          TextButton(
            onPressed: _saveServer,
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info Section
            _sectionTitle('Server Identity'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Server Name',
                hintText: 'e.g. Production Cluster',
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Server name is required' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host / IP Address',
                      hintText: '100.x.x.x or vps.example.com',
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Host/IP is required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '22',
                      helperText: 'Default: 22',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // Optional, defaults to 22
                      final p = int.tryParse(v.trim());
                      if (p == null || p < 1 || p > 65535) {
                        return '1-65535';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'SSH Username',
                hintText: 'cas or root or ubuntu',
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Username is required' : null,
            ),
            const SizedBox(height: 12),

            // Environment Picker
            DropdownButtonFormField<ServerEnvironment>(
              initialValue: _environment,
              decoration: const InputDecoration(labelText: 'Environment'),
              dropdownColor: const Color(0xFF1E293B),
              items: ServerEnvironment.values.map((env) {
                return DropdownMenuItem(
                  value: env,
                  child: Text(env.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _environment = val);
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Docker, Web API, Nginx, PostgreSQL cluster',
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                hintText: 'production, api, tailscale, docker',
              ),
            ),
            const SizedBox(height: 20),

            // Authentication Section
            _sectionTitle('Authentication & Host Verification'),
            keysAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading keys: $e'),
              data: (keys) {
                if (keys.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x22F59E0B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.envStaging),
                    ),
                    child: const Text(
                      'No SSH keys found in storage. Please go to Settings -> SSH Keys to import an ED25519/RSA private key first.',
                      style: TextStyle(color: Color(0xFFFCD34D), fontSize: 12),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: keys.any((k) => k.id == _selectedKeyId) ? _selectedKeyId : null,
                  decoration: const InputDecoration(
                    labelText: 'Select SSH Private Key',
                    hintText: 'Choose from imported keys',
                  ),
                  dropdownColor: const Color(0xFF1E293B),
                  items: keys.map((k) {
                    return DropdownMenuItem(
                      value: k.id,
                      child: Text('${k.name} (${k.keyType})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedKeyId = val),
                  validator: (v) => v == null ? 'Please select an SSH key' : null,
                );
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _fingerprintController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: const InputDecoration(
                labelText: 'Trusted Host Key Fingerprint (SHA256:...)',
                hintText: 'SHA256:xxxxxx (Discovered during Test Connection)',
              ),
            ),
            const SizedBox(height: 16),

            // Test Connection Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _isTesting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bolt, size: 16),
                label: Text(_isTesting ? 'TESTING CONNECTION...' : 'TEST SSH CONNECTION'),
                onPressed: _isTesting ? null : _testConnection,
              ),
            ),
            const SizedBox(height: 20),

            // Server Profile Customization (Section 23)
            _sectionTitle('Server Container Profile (Optional)'),
            const Text(
              'Customize container names for this server to automatically tailor Docker & Nginx commands.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _nginxController,
              decoration: const InputDecoration(labelText: 'Nginx Container', hintText: 'e.g. nginx_cas'),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _postgresController,
              decoration: const InputDecoration(labelText: 'Postgres Container', hintText: 'e.g. postgres'),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _redisController,
              decoration: const InputDecoration(labelText: 'Redis Container', hintText: 'e.g. redis'),
            ),
            const SizedBox(height: 16),

            // HTTP Health Endpoint (Section 24)
            _sectionTitle('HTTP Health Check (Optional)'),
            TextFormField(
              controller: _httpHealthNameController,
              decoration: const InputDecoration(labelText: 'Endpoint Name', hintText: 'e.g. Primary API Health'),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _httpHealthUrlController,
              decoration: const InputDecoration(
                labelText: 'Health URL',
                hintText: 'https://api.example.com/health',
              ),
            ),
            const SizedBox(height: 32),

            // Save Server Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlueDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saveServer,
              child: const Text('SAVE SERVER CONFIGURATION', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (widget.existingServer != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.statusRed,
                  side: const BorderSide(color: AppTheme.statusRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('DELETE THIS SERVER'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Server?'),
                      content: Text('Are you sure you want to delete "${widget.existingServer!.name}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCEL')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await ref.read(serverListProvider.notifier).deleteServer(widget.existingServer!.id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Server "${widget.existingServer!.name}" deleted.'),
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
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
