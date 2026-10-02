import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/biometric_service.dart';
import 'storage_providers.dart';

class AppLockState {
  final bool isEnabled;
  final bool isLocked;

  const AppLockState({
    required this.isEnabled,
    required this.isLocked,
  });

  AppLockState copyWith({bool? isEnabled, bool? isLocked}) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  final SharedPreferences _prefs;
  final BiometricService _biometricService;
  static const String _keyEnabled = 'cas_ops_app_lock_enabled';

  AppLockNotifier(this._prefs, this._biometricService)
      : super(AppLockState(
          isEnabled: _prefs.getBool(_keyEnabled) ?? false,
          isLocked: _prefs.getBool(_keyEnabled) ?? false,
        ));

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      final success = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric app lock',
      );
      if (!success) return;
    }
    await _prefs.setBool(_keyEnabled, enabled);
    state = state.copyWith(isEnabled: enabled, isLocked: false);
  }

  Future<bool> unlock() async {
    if (!state.isEnabled) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    final success = await _biometricService.authenticate(
      reason: 'Authenticate to access EnvOps',
    );
    if (success) {
      state = state.copyWith(isLocked: false);
    }
    return success;
  }

  void lock() {
    if (state.isEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final biometric = ref.watch(biometricServiceProvider);
  return AppLockNotifier(prefs, biometric);
});
