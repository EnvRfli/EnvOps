import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/server_config.dart';
import '../../../domain/repositories/ssh_repository.dart';
import '../../providers/server_providers.dart';
import '../../providers/storage_providers.dart';
import '../../widgets/env_badge.dart';
import '../../widgets/host_key_mismatch_dialog.dart';
import '../../widgets/terminal_toolbar.dart';

class InteractiveTerminalScreen extends ConsumerStatefulWidget {
  final ServerConfig server;

  const InteractiveTerminalScreen({super.key, required this.server});

  @override
  ConsumerState<InteractiveTerminalScreen> createState() => _InteractiveTerminalScreenState();
}

class _InteractiveTerminalScreenState extends ConsumerState<InteractiveTerminalScreen> {
  late final Terminal _terminal;
  InteractiveShell? _shell;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 2000);
    _terminal.onOutput = (data) {
      if (_shell != null && _isConnected) {
        _shell!.write(Uint8List.fromList(utf8.encode(data)));
      }
    };
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (_shell != null && _isConnected) {
        _shell!.resize(width, height);
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.server.isProduction) {
        _showProductionWarning();
      } else {
        _connect();
      }
    });
  }

  void _showProductionWarning() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1724),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.envProd, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.envProd, size: 26),
            SizedBox(width: 8),
            Text(
              'PRODUCTION SERVER',
              style: TextStyle(
                color: AppTheme.envProd,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are connected to:\n${widget.server.name} (${widget.server.hostname})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Commands entered in this terminal are executed directly on the production server without confirmation prompts.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Proceed with caution.',
              style: TextStyle(color: AppTheme.envProd, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              Navigator.of(context).pop(); // Go back
            },
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.envProd,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              _connect();
            },
            child: const Text('ENTER PRODUCTION TERMINAL'),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    _terminal.write('\x1B[33mConnecting to ${widget.server.hostname}:${widget.server.port} as ${widget.server.username}...\x1B[0m\r\n');

    final ssh = ref.read(sshRepositoryProvider);
    try {
      final shell = await ssh.openShell(widget.server);
      _shell = shell;

      _stdoutSub = shell.stdout.listen((bytes) {
        _terminal.write(utf8.decode(bytes, allowMalformed: true));
      });

      _stderrSub = shell.stderr.listen((bytes) {
        _terminal.write('\x1B[31m${utf8.decode(bytes, allowMalformed: true)}\x1B[0m');
      });

      shell.exitCode.then((code) {
        if (mounted) {
          setState(() => _isConnected = false);
          _terminal.write('\r\n\x1B[33m[Session closed with exit code: $code]\x1B[0m\r\n');
        }
      });

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
        });
        _terminal.write('\r\n\x1B[31m[Connection Error: $e]\x1B[0m\r\n');

        if (e is HostKeyMismatchFailure) {
          _handleHostKeyMismatch(e);
        }
      }
    }
  }

  void _handleHostKeyMismatch(HostKeyMismatchFailure failure) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HostKeyMismatchDialog(
        failure: failure,
        onAbort: () {},
        onUpdateTrustedFingerprint: (newFp) async {
          final updated = widget.server.copyWith(
            hostKeyFingerprint: newFp,
            updatedAt: DateTime.now(),
          );
          await ref.read(serverListProvider.notifier).saveServer(updated);
          _connect();
        },
      ),
    );
  }

  void _sendBytes(Uint8List bytes) {
    if (_shell != null && _isConnected) {
      _shell!.write(bytes);
    }
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _shell?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.terminalBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF131B2E),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.server.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.server.username}@${widget.server.hostname}:${widget.server.port}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            EnvBadge(environment: widget.server.environment, isDense: true),
          ],
        ),
        actions: [
          if (_isConnecting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
              ),
            )
          else if (!_isConnected)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: AppTheme.primaryBlue),
              tooltip: 'Reconnect',
              onPressed: _connect,
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: AppTheme.statusRed),
              tooltip: 'Disconnect',
              onPressed: () {
                _shell?.close();
                setState(() => _isConnected = false);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Production Warning Sub-header
          if (widget.server.isProduction)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              color: const Color(0x33EF4444),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 12, color: AppTheme.envProd),
                  SizedBox(width: 6),
                  Text(
                    'PRODUCTION SESSION ACTIVE - COMMANDS EXECUTE LIVE',
                    style: TextStyle(
                      color: AppTheme.envProd,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

          // Terminal View Area
          Expanded(
            child: Container(
              color: AppTheme.terminalBg,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: TerminalView(
                _terminal,
                backgroundOpacity: 1.0,
              ),
            ),
          ),

          // Mobile Helper Toolbar
          TerminalToolbar(onSendBytes: _sendBytes),
        ],
      ),
    );
  }
}
