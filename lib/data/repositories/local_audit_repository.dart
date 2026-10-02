import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/audit_log.dart';
import '../../domain/repositories/audit_repository.dart';

class LocalAuditRepository implements AuditRepository {
  static const String _storageKey = 'cas_ops_audit_logs_v1';
  static const int _maxLogs = 300;
  final SharedPreferences _prefs;

  LocalAuditRepository(this._prefs);

  @override
  Future<List<AuditLogEntry>> getLogs() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addLog(AuditLogEntry entry) async {
    final logs = await getLogs();
    logs.insert(0, entry); // Most recent first
    if (logs.length > _maxLogs) {
      logs.removeRange(_maxLogs, logs.length);
    }
    final jsonString = jsonEncode(logs.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  @override
  Future<void> clearLogs() async {
    await _prefs.remove(_storageKey);
  }
}
