import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/full_diagnose_service.dart';
import '../../../domain/models/server_config.dart';
import '../../providers/storage_providers.dart';
import '../../widgets/env_badge.dart';

class FullDiagnoseScreen extends ConsumerStatefulWidget {
  final ServerConfig server;

  const FullDiagnoseScreen({super.key, required this.server});

  @override
  ConsumerState<FullDiagnoseScreen> createState() => _FullDiagnoseScreenState();
}

class _FullDiagnoseScreenState extends ConsumerState<FullDiagnoseScreen> {
  bool _isRunning = false;
  String _currentStep = '';
  FullDiagnoseReport? _report;
  String? _errorMessage;
  final TextEditingController _problemInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDiagnosis();
  }

  @override
  void dispose() {
    _problemInputController.dispose();
    super.dispose();
  }

  Future<void> _startDiagnosis() async {
    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _currentStep = 'Initializing SSH connection...';
    });

    final service = ref.read(fullDiagnoseServiceProvider);
    try {
      final rep = await service.runDiagnosis(
        widget.server,
        onProgress: (step) {
          if (mounted) setState(() => _currentStep = step);
        },
      );
      if (mounted) {
        setState(() {
          _isRunning = false;
          _report = rep;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _copyToClipboard(String text, String successMsg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMsg),
        backgroundColor: AppTheme.statusGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAiCopyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.accentCyan, size: 22),
                SizedBox(width: 8),
                Text(
                  'Copy for AI (ChatGPT / Claude)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Formats the diagnostic data into an incident analysis prompt. Sensitive credentials and private keys will be automatically redacted.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _problemInputController,
              decoration: const InputDecoration(
                labelText: 'Specific issue or symptom (optional)',
                hintText: 'e.g. Web API container restarting with 502 Bad Gateway',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: AppTheme.statusYellow),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Automated redaction removes passwords, tokens, DB URLs, and keys. Always review before sharing.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('COPY AI INCIDENT PROMPT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlueDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  final prompt = _report!.toAiPromptText(
                    problemDescription: _problemInputController.text.trim(),
                  );
                  Navigator.of(ctx).pop();
                  _copyToClipboard(prompt, 'AI Diagnostic Report copied to clipboard!');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Full System Diagnose', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${widget.server.name} (${widget.server.environment.label})',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          if (!_isRunning && _report != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Re-run Diagnose',
              onPressed: _startDiagnosis,
            ),
          ],
        ],
      ),
      body: _isRunning
          ? _buildProgressView()
          : (_errorMessage != null ? _buildErrorView() : _buildReportView()),
      bottomNavigationBar: (!_isRunning && _report != null)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF131B2E),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_all, size: 16),
                        label: const Text('COPY ALL'),
                        onPressed: () {
                          _copyToClipboard(
                            _report!.toStandardText(),
                            'Standard Diagnostic output copied!',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('COPY FOR AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                        ),
                        onPressed: _showAiCopyModal,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildProgressView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryBlue),
            const SizedBox(height: 20),
            const Text(
              'Running Read-Only Diagnostic Suite',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _currentStep,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.statusRed),
            const SizedBox(height: 16),
            const Text('Diagnosis Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _startDiagnosis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView() {
    final report = _report!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    report.server.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  EnvBadge(environment: report.server.environment),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Host: ${report.server.hostname} • Checks: ${report.sections.length} completed',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip('Docker: ${report.healthSummary.dockerRunning} running', AppTheme.statusGreen),
                  if (report.healthSummary.dockerRestarting > 0)
                    _chip('${report.healthSummary.dockerRestarting} restarting', AppTheme.statusRed),
                  if (report.healthSummary.dockerUnhealthy > 0)
                    _chip('${report.healthSummary.dockerUnhealthy} unhealthy', AppTheme.statusYellow),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Section Cards
        for (final sec in report.sections) ...[
          _buildSectionCard(sec),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionCard(DiagnoseResultSection section) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Text(
          section.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        trailing: section.isAvailable
            ? const Icon(Icons.check_circle_outline, color: AppTheme.statusGreen, size: 18)
            : const Icon(Icons.info_outline, color: AppTheme.statusYellow, size: 18),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.terminalBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: SelectableText(
              section.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
