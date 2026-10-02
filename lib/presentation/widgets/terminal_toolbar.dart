import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TerminalToolbar extends StatefulWidget {
  final void Function(Uint8List bytes) onSendBytes;

  const TerminalToolbar({super.key, required this.onSendBytes});

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

class _TerminalToolbarState extends State<TerminalToolbar> {
  bool _ctrlActive = false;

  void _sendString(String str) {
    widget.onSendBytes(Uint8List.fromList(utf8.encode(str)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF131B2E),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // CTRL Modifier Toggle
          _buildButton(
            label: 'CTRL',
            isActive: _ctrlActive,
            onPressed: () {
              setState(() => _ctrlActive = !_ctrlActive);
            },
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: 'TAB',
            onPressed: () => _sendString('\t'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: 'ESC',
            onPressed: () => _sendString('\x1b'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: '↑',
            onPressed: () => _sendString('\x1b[A'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: '↓',
            onPressed: () => _sendString('\x1b[B'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: '←',
            onPressed: () => _sendString('\x1b[D'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: '→',
            onPressed: () => _sendString('\x1b[C'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: 'CTRL+C',
            onPressed: () => _sendString('\x03'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: 'CTRL+D',
            onPressed: () => _sendString('\x04'),
          ),
          const SizedBox(width: 4),
          _buildButton(
            label: 'CTRL+L',
            onPressed: () => _sendString('\x0c'),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? AppTheme.primaryBlue : const Color(0xFF243049),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : const Color(0xFFE2E8F0),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
