import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../providers/server_providers.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final ServerConnectionStatus status;

  const ConnectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    switch (status) {
      case ServerConnectionStatus.connected:
        dotColor = AppTheme.statusGreen;
        break;
      case ServerConnectionStatus.connecting:
        dotColor = AppTheme.statusYellow;
        break;
      case ServerConnectionStatus.error:
        dotColor = AppTheme.statusRed;
        break;
      case ServerConnectionStatus.disconnected:
      case ServerConnectionStatus.unknown:
        dotColor = AppTheme.statusGray;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: status == ServerConnectionStatus.connected
                ? [BoxShadow(color: dotColor.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1)]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: TextStyle(
            color: dotColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
