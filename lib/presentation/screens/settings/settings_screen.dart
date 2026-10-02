import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_lock_provider.dart';
import '../../providers/server_providers.dart';
import '../../providers/ssh_key_providers.dart';
import '../../providers/storage_providers.dart';
import '../keys/ssh_keys_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLockState = ref.watch(appLockProvider);
    final isMockMode = ref.watch(mockModeProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Settings & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Security Section
          _sectionHeader('SECURITY & CREDENTIALS'),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined, color: AppTheme.primaryBlue),
            title: const Text('SSH Keys Management'),
            subtitle: const Text('Import OpenSSH private keys, view fingerprints', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SshKeysScreen()),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint, color: AppTheme.accentCyan),
            title: const Text('Biometric / App Lock'),
            subtitle: const Text('Protect terminal access and credentials with fingerprint or device PIN', style: TextStyle(fontSize: 12)),
            value: appLockState.isEnabled,
            onChanged: (val) async {
              await ref.read(appLockProvider.notifier).setEnabled(val);
            },
          ),
          const Divider(color: Color(0xFF334155)),

          // Backup & Device Migration Section
          _sectionHeader('BACKUP & DEVICE MIGRATION'),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined, color: AppTheme.accentCyan),
            title: const Text('Export Encrypted Backup'),
            subtitle: const Text('Export all servers and SSH keys with a Master Password', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showExportDialog(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: AppTheme.primaryBlue),
            title: const Text('Import Encrypted Backup'),
            subtitle: const Text('Restore server configurations and keys onto this device', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showImportDialog(context, ref),
          ),
          const Divider(color: Color(0xFF334155)),

          // Developer & Diagnostics Section
          _sectionHeader('DEVELOPER & ENVIRONMENT'),
          SwitchListTile(
            secondary: const Icon(Icons.developer_mode, color: AppTheme.envStaging),
            title: const Text('Dev / Mock Mode'),
            subtitle: const Text('Simulate VPS servers and interactive terminal without live SSH network', style: TextStyle(fontSize: 12)),
            value: isMockMode,
            onChanged: (val) {
              ref.read(mockModeProvider.notifier).setMode(val);
              ref.read(serverListProvider.notifier).loadServers();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'Mock Mode Enabled' : 'Live SSH Mode Enabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: AppTheme.statusRed),
            title: const Text('Clear All Demo / Seed Servers', style: TextStyle(color: AppTheme.statusRed)),
            subtitle: const Text('Remove all pre-seeded demo/mock servers from the database', style: TextStyle(fontSize: 12)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Demo Servers?'),
                  content: const Text('Are you sure you want to remove all demo servers from the dashboard?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCEL')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await ref.read(serverListProvider.notifier).clearAllServers();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All demo servers cleared from dashboard.'),
                              backgroundColor: AppTheme.statusGreen,
                            ),
                          );
                        }
                      },
                      child: const Text('CLEAR ALL'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF334155)),

          // Security Model Information
          _sectionHeader('ABOUT ENVOPS'),
          const ListTile(
            leading: Icon(Icons.shield_outlined, color: AppTheme.statusGreen),
            title: Text('Security Architecture'),
            subtitle: Text(
              'Direct peer-to-peer SSH over private/Tailscale network. Zero external cloud servers. Strict SHA256 host-key verification with mismatch blocking.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
            title: Text('Version'),
            subtitle: Text('EnvOps v1.0.0 (Production Build)', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool isObscured = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text('Export Backup', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a Master Password to encrypt all 5 servers and SSH private keys with AES-256-CBC:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: isObscured,
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off, size: 18),
                      onPressed: () => setDialogState(() => isObscured = !isObscured),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmController,
                  obscureText: isObscured,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlueDark),
              onPressed: () async {
                final pwd = passwordController.text.trim();
                final confirm = confirmController.text.trim();
                if (pwd.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                if (pwd != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }

                Navigator.of(ctx).pop();
                try {
                  final backupService = ref.read(backupServiceProvider);
                  final payload = await backupService.exportEncryptedBackup(pwd);
                  if (context.mounted) {
                    _showExportReadyDialog(context, payload);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.statusRed),
                    );
                  }
                }
              },
              child: const Text('GENERATE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportReadyDialog(BuildContext context, String payload) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.statusGreen),
            SizedBox(width: 8),
            Text('Backup Ready', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your servers and SSH keys are encrypted. Copy this string and send it to your mobile phone (via WhatsApp, Telegram Saved Messages, Notes, or Email):',
              style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  payload,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('DONE'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusGreen),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('COPY TO CLIPBOARD'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: payload));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Encrypted backup copied to clipboard! Paste it to your phone.'),
                  backgroundColor: AppTheme.statusGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final payloadController = TextEditingController();
    final passwordController = TextEditingController();
    bool isObscured = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_download_outlined, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Text('Import Backup', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste the encrypted backup text and enter the Master Password:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payloadController,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    labelText: 'Encrypted Payload',
                    hintText: 'CASOPS_ENC_V1:...',
                    alignLabelWithHint: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste, size: 18),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          setDialogState(() {
                            payloadController.text = data!.text!.trim();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: isObscured,
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off, size: 18),
                      onPressed: () => setDialogState(() => isObscured = !isObscured),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlueDark),
              onPressed: () async {
                final payload = payloadController.text.trim();
                final pwd = passwordController.text.trim();
                if (payload.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please paste the backup payload')),
                  );
                  return;
                }
                if (pwd.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter the master password')),
                  );
                  return;
                }

                try {
                  final backupService = ref.read(backupServiceProvider);
                  final res = await backupService.importEncryptedBackup(payload, pwd);
                  await ref.read(serverListProvider.notifier).loadServers();
                  await ref.read(sshKeyListProvider.notifier).loadKeys();

                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully imported ${res.serverCount} servers and ${res.keyCount} SSH keys!'),
                        backgroundColor: AppTheme.statusGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Import failed: ${e.toString().replaceAll("Exception: ", "")}'),
                        backgroundColor: AppTheme.statusRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('RESTORE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryBlue,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
