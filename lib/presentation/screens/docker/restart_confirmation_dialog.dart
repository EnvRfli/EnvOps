import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/server_config.dart';
import '../../widgets/env_badge.dart';

class RestartConfirmationDialog extends StatefulWidget {
  final ServerConfig server;
  final String targetName; // e.g. container or service name
  final String actionDescription; // e.g. "Restart Docker Container"

  const RestartConfirmationDialog({
    super.key,
    required this.server,
    required this.targetName,
    this.actionDescription = 'Restart Service',
  });

  @override
  State<RestartConfirmationDialog> createState() => _RestartConfirmationDialogState();
}

class _RestartConfirmationDialogState extends State<RestartConfirmationDialog> {
  final TextEditingController _confirmInputController = TextEditingController();
  bool _acknowledged = false;

  @override
  void dispose() {
    _confirmInputController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    if (widget.server.isProduction) {
      return _confirmInputController.text.trim().toUpperCase() == 'CONFIRM RESTART' && _acknowledged;
    }
    return _acknowledged;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: widget.server.isProduction ? AppTheme.envProd : AppTheme.envStaging,
          width: 1.5,
        ),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: widget.server.isProduction ? AppTheme.envProd : AppTheme.envStaging,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.actionDescription}?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                EnvBadge(environment: widget.server.environment),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.server.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers, size: 16, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.targetName,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ This operation will temporarily interrupt the service while it restarts.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Checkbox acknowledgment
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _acknowledged,
              activeColor: AppTheme.envStaging,
              onChanged: (val) => setState(() => _acknowledged = val ?? false),
              title: const Text(
                'I understand the service interruption risk',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),

            // Stricter confirmation for Production servers
            if (widget.server.isProduction) ...[
              const SizedBox(height: 8),
              const Text(
                'PRODUCTION SAFEGUARD: Type "CONFIRM RESTART" to proceed:',
                style: TextStyle(
                  color: AppTheme.envProd,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmInputController,
                autocorrect: false,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'CONFIRM RESTART',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.server.isProduction ? AppTheme.envProd : AppTheme.envStaging,
            foregroundColor: Colors.white,
          ),
          onPressed: _canProceed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('RESTART'),
        ),
      ],
    );
  }
}
