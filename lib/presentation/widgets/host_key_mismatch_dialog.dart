import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_theme.dart';

class HostKeyMismatchDialog extends StatelessWidget {
  final HostKeyMismatchFailure failure;
  final VoidCallback onAbort;
  final ValueChanged<String> onUpdateTrustedFingerprint;

  const HostKeyMismatchDialog({
    super.key,
    required this.failure,
    required this.onAbort,
    required this.onUpdateTrustedFingerprint,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1724),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.statusRed, width: 2),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.statusRed, size: 28),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'HOST KEY MISMATCH',
              style: TextStyle(
                color: AppTheme.statusRed,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠️ CONNECTION BLOCKED!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The SSH host key identity presented by ${failure.host}:${failure.port} has changed since it was recorded. This could indicate a Man-in-the-Middle attack or a re-installed server.',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
            const SizedBox(height: 14),
            _buildFingerprintBox('Expected Trusted Fingerprint', failure.expectedFingerprint, AppTheme.statusGreen),
            const SizedBox(height: 8),
            _buildFingerprintBox('Received Host Fingerprint', failure.receivedFingerprint, AppTheme.statusRed),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x22EF4444),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x55EF4444)),
              ),
              child: const Text(
                'Security Warning: Do not accept this change unless you verified the new fingerprint out-of-band directly on the server console.',
                style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onAbort();
          },
          child: const Text('DISCONNECT & ABORT', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.statusRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onUpdateTrustedFingerprint(failure.receivedFingerprint);
          },
          child: const Text('TRUST NEW FINGERPRINT'),
        ),
      ],
    );
  }

  Widget _buildFingerprintBox(String label, String fingerprint, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          SelectableText(
            fingerprint.isNotEmpty ? fingerprint : '(none recorded)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
