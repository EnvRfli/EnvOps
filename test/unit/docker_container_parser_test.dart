import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/domain/models/docker_container.dart';

void main() {
  group('DockerContainer JSON and Table Parsers', () {
    test('parses json formatted docker ps output', () {
      const sampleJsonLines = '''
{"ID":"e7a8f192b0c1","Names":"nginx_proxy","Image":"nginx:alpine","State":"running","Status":"Up 2 days","Ports":"0.0.0.0:80->80/tcp"}
{"ID":"98f23a100ce4","Names":"api_gateway_service","Image":"app/api-gateway:1.0","State":"restarting","Status":"Restarting (1) 20s ago","Ports":""}
''';

      final containers = DockerContainer.parseJsonLines(sampleJsonLines);
      expect(containers.length, 2);

      final nginx = containers[0];
      expect(nginx.primaryName, 'nginx_proxy');
      expect(nginx.isRunning, isTrue);
      expect(nginx.isRestarting, isFalse);

      final middleware = containers[1];
      expect(middleware.primaryName, 'api_gateway_service');
      expect(middleware.isRestarting, isTrue);
      expect(middleware.isRunning, isFalse);
    });

    test('parses table formatted docker ps fallback output', () {
      const sampleTable = '''
CONTAINER ID   IMAGE                 STATUS                    NAMES
e7a8f192b0c1   nginx:alpine          Up 2 days                 nginx_proxy
4b1c8f309d2a   postgres:16-alpine    Up 5 days                 postgres
''';

      final containers = DockerContainer.parseTableOutput(sampleTable);
      expect(containers.length, 2);
      expect(containers[0].primaryName, 'nginx_proxy');
      expect(containers[0].isRunning, isTrue);
      expect(containers[1].primaryName, 'postgres');
    });
  });
}
