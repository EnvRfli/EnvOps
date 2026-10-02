import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/ssh_key_model.dart';
import '../../providers/ssh_key_providers.dart';

class SshKeysScreen extends ConsumerStatefulWidget {
  const SshKeysScreen({super.key});

  @override
  ConsumerState<SshKeysScreen> createState() => _SshKeysScreenState();
}

class _SshKeysScreenState extends ConsumerState<SshKeysScreen> {
  void _showImportKeyDialog() {
    final nameController = TextEditingController();
    final keyContentController = TextEditingController();
    final passphraseController = TextEditingController();
    bool isPasswordObscured = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, color: AppTheme.primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Import SSH Private Key',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Supports OpenSSH ED25519 or RSA private keys. Keys are stored encrypted inside Android Keystore / Keychain and never leave the device.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Key Label / Name',
                    hintText: 'e.g. CAS Mobile Ops (ED25519)',
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: keyContentController,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: const InputDecoration(
                    labelText: 'Private Key PEM Content',
                    hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----',
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: passphraseController,
                  obscureText: isPasswordObscured,
                  decoration: InputDecoration(
                    labelText: 'Key Passphrase (optional)',
                    hintText: 'Leave empty if unencrypted',
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordObscured ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                        color: Colors.white60,
                      ),
                      onPressed: () {
                        setModalState(() => isPasswordObscured = !isPasswordObscured);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('IMPORT & SECURE KEY'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final content = keyContentController.text.trim();
                      final pass = passphraseController.text;

                      if (name.isEmpty || content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a key name and private key content.'),
                            backgroundColor: AppTheme.statusRed,
                          ),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await ref.read(sshKeyListProvider.notifier).importKey(
                              name: name,
                              privateKeyPem: content,
                              passphrase: pass.isNotEmpty ? pass : null,
                            );
                        if (mounted) {
                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Key "$name" securely imported!'),
                              backgroundColor: AppTheme.statusGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to import key: $e'),
                              backgroundColor: AppTheme.statusRed,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteKey(SshKeyModel key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete SSH Key?'),
        content: Text(
          'Are you sure you want to permanently delete "${key.name}"? Servers referencing this key will no longer be able to authenticate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(sshKeyListProvider.notifier).deleteKey(key.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted key ${key.name}'), backgroundColor: AppTheme.statusGreen),
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
    final keysAsync = ref.watch(sshKeyListProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('SSH Keys'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22, color: AppTheme.primaryBlue),
            tooltip: 'Import Key',
            onPressed: _showImportKeyDialog,
          ),
        ],
      ),
      body: keysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
        error: (err, _) => Center(child: Text('Error loading keys: $err')),
        data: (keys) {
          if (keys.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.key_off_outlined, size: 48, color: Color(0xFF64748B)),
                    const SizedBox(height: 16),
                    const Text('No SSH Keys Configured', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      'Import your OpenSSH private key (ED25519 recommended) to connect to your VPS instances.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Import Private Key'),
                      onPressed: _showImportKeyDialog,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: keys.length,
            itemBuilder: (ctx, idx) {
              final k = keys[idx];
              return Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x2238BDF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.vpn_key, color: AppTheme.primaryBlue, size: 20),
                  ),
                  title: Text(
                    k.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              k.keyType,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (k.hasPassphrase)
                            const Text(
                              '• Encrypted with Passphrase',
                              style: TextStyle(fontSize: 11, color: AppTheme.statusYellow),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Fingerprint: ${k.publicKeyFingerprint}',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => _confirmDeleteKey(k),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryBlueDark,
        onPressed: _showImportKeyDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
