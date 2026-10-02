import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../keys/ssh_keys_screen.dart';
import '../servers/add_edit_server_screen.dart';

class FirstRunScreen extends StatelessWidget {
  final VoidCallback onDismiss;

  const FirstRunScreen({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal, color: AppTheme.primaryBlue, size: 36),
                  SizedBox(width: 10),
                  Text(
                    'ENVOPS',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Secure Linux VPS Operations from Mobile',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Monitor Docker clusters, PostgreSQL, Redis, and run diagnostics without typing long shell commands on your phone keyboard.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
              ),
              const SizedBox(height: 36),

              _stepItem('1', 'Import OpenSSH Key', 'Save your ED25519 private key securely inside Android Keystore.', () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SshKeysScreen()),
                );
              }),
              const SizedBox(height: 16),

              _stepItem('2', 'Add Linux VPS Server', 'Configure host IP (Tailscale / private network), username, and port.', () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddEditServerScreen()),
                );
              }),
              const SizedBox(height: 16),

              _stepItem('3', 'Test & Verify Host Key', 'Verify the SHA256 host fingerprint and test SSH handshake.', onDismiss),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlueDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onDismiss,
                  child: const Text('GET STARTED', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepItem(String number, String title, String description, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlueDark,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                number,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
