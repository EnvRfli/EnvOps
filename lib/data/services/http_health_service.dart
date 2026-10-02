import 'dart:async';
import 'package:http/http.dart' as http;
import '../../domain/models/server_profile.dart';

class HttpHealthResult {
  final HttpHealthEndpoint endpoint;
  final int? statusCode;
  final bool isHealthy;
  final Duration latency;
  final String? errorMessage;

  const HttpHealthResult({
    required this.endpoint,
    this.statusCode,
    required this.isHealthy,
    required this.latency,
    this.errorMessage,
  });

  String get summary {
    if (isHealthy) {
      return '${endpoint.name} ${statusCode ?? 200} OK (${latency.inMilliseconds}ms)';
    } else if (statusCode != null) {
      return '${endpoint.name} $statusCode ERROR (${latency.inMilliseconds}ms)';
    } else {
      return '${endpoint.name} FAILED: ${errorMessage ?? "Timeout"}';
    }
  }
}

class HttpHealthService {
  final http.Client _client;

  HttpHealthService([http.Client? client]) : _client = client ?? http.Client();

  Future<HttpHealthResult> checkEndpoint(HttpHealthEndpoint endpoint) async {
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse(endpoint.url);
      final response = await _client.get(uri).timeout(
            Duration(seconds: endpoint.timeoutSeconds),
          );
      stopwatch.stop();

      final isHealthy = response.statusCode == endpoint.expectedStatusCode;
      return HttpHealthResult(
        endpoint: endpoint,
        statusCode: response.statusCode,
        isHealthy: isHealthy,
        latency: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      return HttpHealthResult(
        endpoint: endpoint,
        isHealthy: false,
        latency: stopwatch.elapsed,
        errorMessage: 'Request timed out after ${endpoint.timeoutSeconds}s',
      );
    } catch (e) {
      stopwatch.stop();
      return HttpHealthResult(
        endpoint: endpoint,
        isHealthy: false,
        latency: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    }
  }

  Future<List<HttpHealthResult>> checkAll(List<HttpHealthEndpoint> endpoints) async {
    final futures = endpoints.map((ep) => checkEndpoint(ep));
    return await Future.wait(futures);
  }
}
