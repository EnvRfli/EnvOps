class SshKeyModel {
  final String id;
  final String name;
  final String keyType; // 'ED25519', 'RSA', 'ECDSA', etc.
  final String publicKeyFingerprint; // SHA256 of public key or key preview
  final bool hasPassphrase;
  final DateTime createdAt;
  final List<String> associatedServerIds;

  const SshKeyModel({
    required this.id,
    required this.name,
    required this.keyType,
    required this.publicKeyFingerprint,
    required this.hasPassphrase,
    required this.createdAt,
    this.associatedServerIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'keyType': keyType,
        'publicKeyFingerprint': publicKeyFingerprint,
        'hasPassphrase': hasPassphrase,
        'createdAt': createdAt.toIso8601String(),
        'associatedServerIds': associatedServerIds,
      };

  factory SshKeyModel.fromJson(Map<String, dynamic> json) => SshKeyModel(
        id: json['id'] as String,
        name: json['name'] as String,
        keyType: json['keyType'] as String? ?? 'ED25519',
        publicKeyFingerprint: json['publicKeyFingerprint'] as String? ?? '',
        hasPassphrase: json['hasPassphrase'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        associatedServerIds:
            (json['associatedServerIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      );

  SshKeyModel copyWith({
    String? id,
    String? name,
    String? keyType,
    String? publicKeyFingerprint,
    bool? hasPassphrase,
    DateTime? createdAt,
    List<String>? associatedServerIds,
  }) {
    return SshKeyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      keyType: keyType ?? this.keyType,
      publicKeyFingerprint: publicKeyFingerprint ?? this.publicKeyFingerprint,
      hasPassphrase: hasPassphrase ?? this.hasPassphrase,
      createdAt: createdAt ?? this.createdAt,
      associatedServerIds: associatedServerIds ?? this.associatedServerIds,
    );
  }
}
