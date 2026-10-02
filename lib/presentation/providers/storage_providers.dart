import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/secure_storage_service.dart';
import '../../data/repositories/dartssh2_repository.dart';
import '../../data/repositories/local_audit_repository.dart';
import '../../data/repositories/local_server_repository.dart';
import '../../data/repositories/local_ssh_key_repository.dart';
import '../../data/repositories/mock_ssh_repository.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/full_diagnose_service.dart';
import '../../data/services/http_health_service.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/repositories/server_repository.dart';
import '../../domain/repositories/ssh_key_repository.dart';
import '../../domain/repositories/ssh_repository.dart';

// SharedPreferences must be overridden at main() init
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalServerRepository(prefs);
});

final sshKeyRepositoryProvider = Provider<SshKeyRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return LocalSshKeyRepository(prefs, secureStorage);
});

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalAuditRepository(prefs);
});

// Mock mode toggle (defaults to false in production)
class MockModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const String _key = 'cas_ops_mock_mode';

  MockModeNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  void toggle() {
    state = !state;
    _prefs.setBool(_key, state);
  }

  void setMode(bool enabled) {
    state = enabled;
    _prefs.setBool(_key, enabled);
  }
}

final mockModeProvider = StateNotifierProvider<MockModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MockModeNotifier(prefs);
});

final mockSshRepositorySingleton = MockSshRepository();

final sshRepositoryProvider = Provider<SshRepository>((ref) {
  final isMock = ref.watch(mockModeProvider);
  if (isMock) {
    return mockSshRepositorySingleton;
  }
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return DartSshRepository(secureStorage);
});

final fullDiagnoseServiceProvider = Provider<FullDiagnoseService>((ref) {
  final ssh = ref.watch(sshRepositoryProvider);
  return FullDiagnoseService(ssh);
});

final httpHealthServiceProvider = Provider<HttpHealthService>((ref) {
  return HttpHealthService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final serverRepo = ref.watch(serverRepositoryProvider);
  final keyRepo = ref.watch(sshKeyRepositoryProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return BackupService(
    serverRepository: serverRepo,
    sshKeyRepository: keyRepo,
    secureStorage: secureStorage,
  );
});
