class HttpHealthEndpoint {
  final String id;
  final String name;
  final String url;
  final int expectedStatusCode;
  final int timeoutSeconds;

  const HttpHealthEndpoint({
    required this.id,
    required this.name,
    required this.url,
    this.expectedStatusCode = 200,
    this.timeoutSeconds = 5,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'expectedStatusCode': expectedStatusCode,
        'timeoutSeconds': timeoutSeconds,
      };

  factory HttpHealthEndpoint.fromJson(Map<String, dynamic> json) => HttpHealthEndpoint(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        expectedStatusCode: json['expectedStatusCode'] as int? ?? 200,
        timeoutSeconds: json['timeoutSeconds'] as int? ?? 5,
      );
}

class ServerProfile {
  final String? nginxContainer;
  final String? redisContainer;
  final String? postgresContainer;
  final String? appContainer;
  final List<String> middlewareContainers;
  final List<HttpHealthEndpoint> healthEndpoints;

  const ServerProfile({
    this.nginxContainer,
    this.redisContainer,
    this.postgresContainer,
    this.appContainer,
    this.middlewareContainers = const [],
    this.healthEndpoints = const [],
  });

  Map<String, dynamic> toJson() => {
        'nginxContainer': nginxContainer,
        'redisContainer': redisContainer,
        'postgresContainer': postgresContainer,
        'appContainer': appContainer,
        'middlewareContainers': middlewareContainers,
        'healthEndpoints': healthEndpoints.map((e) => e.toJson()).toList(),
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        nginxContainer: json['nginxContainer'] as String?,
        redisContainer: json['redisContainer'] as String?,
        postgresContainer: json['postgresContainer'] as String?,
        appContainer: json['appContainer'] as String?,
        middlewareContainers: (json['middlewareContainers'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
        healthEndpoints: (json['healthEndpoints'] as List<dynamic>?)
                ?.map((e) => HttpHealthEndpoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  ServerProfile copyWith({
    String? nginxContainer,
    String? redisContainer,
    String? postgresContainer,
    String? appContainer,
    List<String>? middlewareContainers,
    List<HttpHealthEndpoint>? healthEndpoints,
  }) {
    return ServerProfile(
      nginxContainer: nginxContainer ?? this.nginxContainer,
      redisContainer: redisContainer ?? this.redisContainer,
      postgresContainer: postgresContainer ?? this.postgresContainer,
      appContainer: appContainer ?? this.appContainer,
      middlewareContainers: middlewareContainers ?? this.middlewareContainers,
      healthEndpoints: healthEndpoints ?? this.healthEndpoints,
    );
  }
}
