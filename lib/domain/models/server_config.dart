import 'server_profile.dart';

enum ServerEnvironment {
  production,
  staging,
  development,
  monitoring,
  other;

  String get label {
    switch (this) {
      case ServerEnvironment.production:
        return 'PRODUCTION';
      case ServerEnvironment.staging:
        return 'STAGING';
      case ServerEnvironment.development:
        return 'DEVELOPMENT';
      case ServerEnvironment.monitoring:
        return 'MONITORING';
      case ServerEnvironment.other:
        return 'OTHER';
    }
  }

  static ServerEnvironment fromString(String val) {
    return ServerEnvironment.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => ServerEnvironment.other,
    );
  }
}

class ServerConfig {
  final String id;
  final String name;
  final String hostname;
  final int port;
  final String username;
  final ServerEnvironment environment;
  final String description;
  final String? hostKeyFingerprint; // SHA256:...
  final String? keyId; // ID of the stored SSH key
  final ServerProfile profile;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 22,
    required this.username,
    required this.environment,
    this.description = '',
    this.hostKeyFingerprint,
    this.keyId,
    this.profile = const ServerProfile(),
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isProduction => environment == ServerEnvironment.production;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hostname': hostname,
        'port': port,
        'username': username,
        'environment': environment.name,
        'description': description,
        'hostKeyFingerprint': hostKeyFingerprint,
        'keyId': keyId,
        'profile': profile.toJson(),
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        hostname: json['hostname'] as String,
        port: json['port'] as int? ?? 22,
        username: json['username'] as String,
        environment: ServerEnvironment.fromString(json['environment'] as String? ?? 'other'),
        description: json['description'] as String? ?? '',
        hostKeyFingerprint: json['hostKeyFingerprint'] as String?,
        keyId: json['keyId'] as String?,
        profile: json['profile'] != null
            ? ServerProfile.fromJson(json['profile'] as Map<String, dynamic>)
            : const ServerProfile(),
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  ServerConfig copyWith({
    String? id,
    String? name,
    String? hostname,
    int? port,
    String? username,
    ServerEnvironment? environment,
    String? description,
    String? hostKeyFingerprint,
    String? keyId,
    ServerProfile? profile,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      environment: environment ?? this.environment,
      description: description ?? this.description,
      hostKeyFingerprint: hostKeyFingerprint ?? this.hostKeyFingerprint,
      keyId: keyId ?? this.keyId,
      profile: profile ?? this.profile,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
