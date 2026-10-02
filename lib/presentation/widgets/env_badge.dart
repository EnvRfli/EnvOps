import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/server_config.dart';

class EnvBadge extends StatelessWidget {
  final ServerEnvironment environment;
  final bool isDense;

  const EnvBadge({
    super.key,
    required this.environment,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color fg;

    switch (environment) {
      case ServerEnvironment.production:
        bg = const Color(0x33EF4444);
        border = AppTheme.envProd;
        fg = const Color(0xFFFCA5A5);
        break;
      case ServerEnvironment.staging:
        bg = const Color(0x33F59E0B);
        border = AppTheme.envStaging;
        fg = const Color(0xFFFCD34D);
        break;
      case ServerEnvironment.development:
        bg = const Color(0x3310B981);
        border = AppTheme.envDev;
        fg = const Color(0xFF6EE7B7);
        break;
      case ServerEnvironment.monitoring:
        bg = const Color(0x338B5CF6);
        border = AppTheme.envMonitoring;
        fg = const Color(0xFFC4B5FD);
        break;
      case ServerEnvironment.other:
        bg = const Color(0x3364748B);
        border = AppTheme.envOther;
        fg = const Color(0xFFCBD5E1);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 6 : 8,
        vertical: isDense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: environment == ServerEnvironment.production ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (environment == ServerEnvironment.production) ...[
            Icon(Icons.shield_outlined, size: isDense ? 10 : 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            environment.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: isDense ? 10 : 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
