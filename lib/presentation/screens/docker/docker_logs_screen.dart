import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/secret_redactor.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/server_config.dart';
import '../../providers/storage_providers.dart';

class DockerLogsScreen extends ConsumerStatefulWidget {
  final ServerConfig server;
  final String containerName;

  const DockerLogsScreen({
    super.key,
    required this.server,
    required this.containerName,
  });

  @override
  ConsumerState<DockerLogsScreen> createState() => _DockerLogsScreenState();
}

class _DockerLogsScreenState extends ConsumerState<DockerLogsScreen> {
  int _tailCount = 200;
  bool _timestamps = true;
  bool _isFollowing = false;
  bool _isLoading = false;
  final List<String> _logLines = [];
  StreamSubscription<String>? _logSub;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _stopFollowing();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopFollowing() {
    _logSub?.cancel();
    _logSub = null;
    if (mounted) setState(() => _isFollowing = false);
  }

  Future<void> _fetchLogs() async {
    _stopFollowing();
    setState(() {
      _isLoading = true;
      _logLines.clear();
    });

    final ssh = ref.read(sshRepositoryProvider);
    try {
      final cmd =
          'docker logs --tail $_tailCount ${_timestamps ? "--timestamps" : ""} ${widget.containerName}';
      final res = await ssh.execute(
        widget.server,
        cmd,
        timeout: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _logLines.addAll(res.outputCombined.split('\n'));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _logLines.add('[Error loading logs: $e]');
        });
      }
    }
  }

  Future<void> _startFollowing() async {
    _stopFollowing();
    setState(() {
      _isFollowing = true;
    });

    final ssh = ref.read(sshRepositoryProvider);
    try {
      final stream = await ssh.streamLogs(
        widget.server,
        widget.containerName,
        tail: 50,
        timestamps: _timestamps,
      );

      _logSub = stream.listen(
        (line) {
          if (mounted) {
            setState(() {
              _logLines.add(line);
              if (_logLines.length > 2000) {
                _logLines.removeRange(0, 500);
              }
            });
            _scrollToBottom();
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isFollowing = false;
              _logLines.add('[Stream closed: $err]');
            });
          }
        },
        onDone: () {
          if (mounted) setState(() => _isFollowing = false);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _logLines.add('[Error streaming logs: $e]');
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyLogs(bool forAi) {
    final rawText = _logLines.join('\n');
    if (forAi) {
      final buffer = StringBuffer();
      buffer.writeln('ENVOPS DOCKER CONTAINER LOGS');
      buffer.writeln('Server   : ${widget.server.name}');
      buffer.writeln('Container: ${widget.containerName}');
      buffer.writeln('Tail     : $_tailCount lines');
      buffer.writeln('\n--- LOG CONTENT (REDACTED) ---');
      buffer.writeln(SecretRedactor.redact(rawText));
      buffer.writeln('\n--- AI INSTRUCTION ---');
      buffer.writeln(
        'Analyze the logs above for stack traces, connection drops, uncaught exceptions, and performance issues.',
      );
      buffer.writeln('\n${SecretRedactor.disclaimer}');
      Clipboard.setData(ClipboardData(text: buffer.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Redacted logs copied for AI!'),
          backgroundColor: AppTheme.statusGreen,
        ),
      );
    } else {
      Clipboard.setData(ClipboardData(text: rawText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Raw logs copied to clipboard!'),
          backgroundColor: AppTheme.statusGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.terminalBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF131B2E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.containerName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.server.name} • Docker Logs',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy Raw',
            onPressed: () => _copyLogs(false),
          ),
          IconButton(
            icon: const Icon(
              Icons.auto_awesome,
              size: 18,
              color: AppTheme.accentCyan,
            ),
            tooltip: 'Copy for AI',
            onPressed: () => _copyLogs(true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                // Tail Dropdown
                const Text(
                  'Tail: ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                DropdownButton<int>(
                  value: _tailCount,
                  dropdownColor: const Color(0xFF1E293B),
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 50, child: Text('50')),
                    DropdownMenuItem(value: 100, child: Text('100')),
                    DropdownMenuItem(value: 200, child: Text('200')),
                    DropdownMenuItem(value: 500, child: Text('500')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _tailCount = val);
                      _fetchLogs();
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Timestamps Toggle
                InkWell(
                  onTap: () {
                    setState(() => _timestamps = !_timestamps);
                    _fetchLogs();
                  },
                  child: Row(
                    children: [
                      Icon(
                        _timestamps
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: _timestamps
                            ? AppTheme.primaryBlue
                            : Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Time',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Follow / Stop Button
                if (_isFollowing)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop, size: 14),
                    label: const Text('STOP', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: _stopFollowing,
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('FOLLOW', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: _startFollowing,
                  ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh',
                  onPressed: _fetchLogs,
                ),
              ],
            ),
          ),

          // Log Output Viewer
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                  )
                : Container(
                    color: AppTheme.terminalBg,
                    padding: const EdgeInsets.all(8),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _logLines.length,
                      itemBuilder: (ctx, idx) {
                        final line = _logLines[idx];
                        Color color = const Color(0xFFE2E8F0);
                        if (line.toLowerCase().contains('error') ||
                            line.toLowerCase().contains('critical') ||
                            line.toLowerCase().contains('fatal')) {
                          color = const Color(0xFFFCA5A5);
                        } else if (line.toLowerCase().contains('warn')) {
                          color = const Color(0xFFFDE047);
                        }
                        return Text(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
