import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_lock_provider.dart';
import '../providers/server_providers.dart';
import '../providers/ssh_key_providers.dart';
import 'audit/audit_log_screen.dart';
import 'lock/app_lock_screen.dart';
import 'onboarding/first_run_screen.dart';
import 'servers/server_list_screen.dart';
import 'settings/settings_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _dismissedOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background - lock if lock is enabled
      ref.read(appLockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockProvider);
    if (lockState.isLocked) {
      return const AppLockScreen();
    }

    final serversAsync = ref.watch(serverListProvider);
    final keysAsync = ref.watch(sshKeyListProvider);

    final bool isBrandNew = !_dismissedOnboarding &&
        serversAsync.maybeWhen(data: (s) => s.isEmpty, orElse: () => false) &&
        keysAsync.maybeWhen(data: (k) => k.isEmpty, orElse: () => false);

    if (isBrandNew) {
      return FirstRunScreen(
        onDismiss: () => setState(() => _dismissedOnboarding = true),
      );
    }

    final screens = [
      const ServerListScreen(),
      const AuditLogScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dns_outlined),
            activeIcon: Icon(Icons.dns),
            label: 'Servers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
