import '../../core/security/command_risk_analyzer.dart';
import 'server_config.dart';

class AuditLogEntry {
  final String id;
  final DateTime timestamp;
  final String serverId;
  final String serverName;
  final ServerEnvironment environment;
  final String commandText;
  final CommandRisk risk;
  final int exitCode;
  final int durationMs;
  final bool isSuccess;

  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.serverId,
    required this.serverName,
    required this.environment,
    required this.commandText,
    required this.risk,
    required this.exitCode,
    required this.durationMs,
    required this.isSuccess,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'serverId': serverId,
        'serverName': serverName,
        'environment': environment.name,
        'commandText': commandText,
        'risk': risk.name,
        'exitCode': exitCode,
        'durationMs': durationMs,
        'isSuccess': isSuccess,
      };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        serverId: json['serverId'] as String,
        serverName: json['serverName'] as String,
        environment: ServerEnvironment.fromString(json['environment'] as String? ?? 'other'),
        commandText: json['commandText'] as String,
        risk: CommandRisk.values.firstWhere(
          (r) => r.name == json['risk'],
          orElse: () => CommandRisk.readOnly,
        ),
        exitCode: json['exitCode'] as int? ?? 0,
        durationMs: json['durationMs'] as int? ?? 0,
        isSuccess: json['isSuccess'] as bool? ?? false,
      );
}
