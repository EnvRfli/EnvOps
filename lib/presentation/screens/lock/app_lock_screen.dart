import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_lock_provider.dart';

class AppLockScreen extends ConsumerWidget {
  const AppLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 72, color: AppTheme.primaryBlue),
                const SizedBox(height: 24),
                const Text(
                  'ENVOPS LOCKED',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Biometric authentication or device PIN required to access SSH keys and servers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  icon: const Icon(Icons.fingerprint, size: 22),
                  label: const Text('UNLOCK WITH BIOMETRIC / PIN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlueDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () async {
                    await ref.read(appLockProvider.notifier).unlock();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
