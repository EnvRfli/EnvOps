import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/models/audit_log.dart';
import '../../domain/repositories/audit_repository.dart';
import 'storage_providers.dart';

class AuditLogNotifier extends StateNotifier<AsyncValue<List<AuditLogEntry>>> {
  final AuditRepository _repository;

  AuditLogNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadLogs();
  }

  Future<void> loadLogs() async {
    try {
      final logs = await _repository.getLogs();
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> recordLog(AuditLogEntry entry) async {
    await _repository.addLog(entry);
    await loadLogs();
  }

  Future<void> clearAll() async {
    await _repository.clearLogs();
    state = const AsyncValue.data([]);
  }
}

final auditLogProvider = StateNotifierProvider<AuditLogNotifier, AsyncValue<List<AuditLogEntry>>>((ref) {
  final repo = ref.watch(auditRepositoryProvider);
  return AuditLogNotifier(repo);
});
