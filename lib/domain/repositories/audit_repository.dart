import '../models/audit_log.dart';

abstract class AuditRepository {
  Future<List<AuditLogEntry>> getLogs();
  Future<void> addLog(AuditLogEntry entry);
  Future<void> clearLogs();
}
