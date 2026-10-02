import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/security/secret_redactor.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/command_result.dart';
import '../../../domain/models/server_config.dart';

class CommandOutputDialog extends StatelessWidget {
  final ServerConfig server;
  final String commandTitle;
  final String commandText;
  final CommandResult result;

  const CommandOutputDialog({
    super.key,
    required this.server,
    required this.commandTitle,
    required this.commandText,
    required this.result,
  });

  void _copy(BuildContext context, String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.statusGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyForAi(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('ENVOPS COMMAND OUTPUT');
    buffer.writeln('Server     : ${server.name} (${server.environment.label})');
    buffer.writeln('Command    : $commandText');
    buffer.writeln('Exit Code  : ${result.exitCode}');
    buffer.writeln('Duration   : ${result.duration.inMilliseconds}ms');
    buffer.writeln('\n--- OUTPUT (REDACTED) ---');
    buffer.writeln(SecretRedactor.redact(result.outputCombined));
    buffer.writeln('\n--- REQUEST ---');
    buffer.writeln('Analyze the output above. If errors are present, explain potential causes and suggest safe read-only diagnostics.');
    buffer.writeln('\n${SecretRedactor.disclaimer}');

    _copy(context, buffer.toString(), 'Redacted AI snippet copied!');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commandTitle,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          commandText,
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: result.isSuccess ? const Color(0x2222C55E) : const Color(0x22EF4444),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: result.isSuccess ? AppTheme.statusGreen : AppTheme.statusRed),
                    ),
                    child: Text(
                      'Exit ${result.exitCode} (${result.duration.inMilliseconds}ms)',
                      style: TextStyle(
                        fontSize: 10,
                        color: result.isSuccess ? AppTheme.statusGreen : AppTheme.statusRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF334155)),

            // Output Console
            Expanded(
              child: Container(
                width: double.infinity,
                color: AppTheme.terminalBg,
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: SelectableText(
                    result.outputCombined.isNotEmpty ? result.outputCombined : '(No output returned)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: result.exitCode == 0 ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
                    ),
                  ),
                ),
              ),
            ),

            // Footer Actions
            const Divider(height: 1, color: Color(0xFF334155)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('COPY RAW', style: TextStyle(fontSize: 11)),
                    onPressed: () => _copy(context, result.outputCombined, 'Raw output copied!'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('COPY FOR AI', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                    onPressed: () => _copyForAi(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
