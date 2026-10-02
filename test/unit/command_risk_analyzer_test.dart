import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/core/security/command_risk_analyzer.dart';

void main() {
  group('CommandRiskAnalyzer', () {
    test('classifies read-only safe commands as GREEN / readOnly', () {
      expect(CommandRiskAnalyzer.analyze('docker ps'), CommandRisk.readOnly);
      expect(CommandRiskAnalyzer.analyze('docker ps -a'), CommandRisk.readOnly);
      expect(CommandRiskAnalyzer.analyze('docker stats --no-stream'), CommandRisk.readOnly);
      expect(CommandRiskAnalyzer.analyze('free -h'), CommandRisk.readOnly);
      expect(CommandRiskAnalyzer.analyze('df -h'), CommandRisk.readOnly);
      expect(CommandRiskAnalyzer.analyze('uptime'), CommandRisk.readOnly);
      expect(CommandRiskAnalyzer.analyze('ss -lntp'), CommandRisk.readOnly);
      expect(CommandRiskAnalyzer.analyze('ps aux --sort=-%cpu | head -20'), CommandRisk.readOnly);
    });

    test('classifies service restarts as YELLOW / serviceChange', () {
      expect(CommandRiskAnalyzer.analyze('docker restart nginx_cas'), CommandRisk.serviceChange);
      expect(CommandRiskAnalyzer.analyze('docker stop postgres'), CommandRisk.serviceChange);
      expect(CommandRiskAnalyzer.analyze('docker compose restart web'), CommandRisk.serviceChange);
      expect(CommandRiskAnalyzer.analyze('systemctl restart redis'), CommandRisk.serviceChange);
      expect(CommandRiskAnalyzer.analyze('nginx -s reload'), CommandRisk.serviceChange);
    });

    test('classifies destructive commands as RED / destructive and blocks quick action', () {
      final dangerousCommands = [
        'rm -rf /var/log/*',
        'rm -f important.txt',
        'shutdown -h now',
        'reboot',
        'mkfs.ext4 /dev/sda1',
        'dd if=/dev/zero of=/dev/sda',
        'docker rm my_container',
        'docker volume rm my_vol',
        'docker system prune -a',
        'docker compose down',
        'DROP DATABASE app_production;',
        'TRUNCATE TABLE users;',
        'DELETE FROM customers WHERE 1=1;',
        'iptables -F',
        'ufw reset',
      ];

      for (final cmd in dangerousCommands) {
        expect(
          CommandRiskAnalyzer.analyze(cmd),
          CommandRisk.destructive,
          reason: 'Command "$cmd" must be classified as destructive',
        );
        expect(
          CommandRiskAnalyzer.isAllowedAsQuickAction(cmd),
          isFalse,
          reason: 'Command "$cmd" must NOT be allowed as quick action',
        );
      }
    });

    test('never downgrades dangerous command even if caller claims readOnly', () {
      final result = CommandRiskAnalyzer.analyze('rm -rf /', CommandRisk.readOnly);
      expect(result, CommandRisk.destructive);
    });
  });
}
