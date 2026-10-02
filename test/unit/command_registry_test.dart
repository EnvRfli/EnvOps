import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/core/security/command_risk_analyzer.dart';
import 'package:env_ops/domain/models/ops_command.dart';

void main() {
  group('OpsCommand Built-in Registry', () {
    test('all built-in commands are registered as READ ONLY for quick safety', () {
      final commands = OpsCommand.defaultBuiltInCommands;
      expect(commands, isNotEmpty);

      for (final cmd in commands) {
        expect(
          cmd.risk,
          equals(CommandRisk.readOnly),
          reason: 'Built-in quick command "${cmd.name}" must be readOnly',
        );
        expect(
          CommandRiskAnalyzer.isAllowedAsQuickAction(cmd.command),
          isTrue,
          reason: 'Built-in command "${cmd.command}" must pass safety check',
        );
      }
    });

    test('built-in registry contains vital categories (system, docker, nginx)', () {
      final commands = OpsCommand.defaultBuiltInCommands;
      final categories = commands.map((c) => c.category).toSet();

      expect(categories.contains(CommandCategory.system), isTrue);
      expect(categories.contains(CommandCategory.docker), isTrue);
      expect(categories.contains(CommandCategory.nginx), isTrue);
    });
  });
}
