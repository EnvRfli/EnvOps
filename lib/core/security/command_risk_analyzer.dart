enum CommandRisk {
  readOnly,      // GREEN: immediate execution allowed
  serviceChange, // YELLOW: requires explicit confirmation
  destructive,   // RED: blocked from quick actions, requires terminal or strict safeguards
}

class CommandRiskAnalyzer {
  CommandRiskAnalyzer._();

  static final List<RegExp> _destructivePatterns = [
    RegExp(r'\brm(\s+-[a-zA-Z]*r[a-zA-Z]*|\s+-[a-zA-Z]*f[a-zA-Z]*|\s+--recursive|\s+--force)?\b', caseSensitive: false),
    RegExp(r'\bshutdown\b', caseSensitive: false),
    RegExp(r'\breboot\b', caseSensitive: false),
    RegExp(r'\bmkfs(\.[a-zA-Z0-9]+)?\b', caseSensitive: false),
    RegExp(r'\bdd\s+if=', caseSensitive: false),
    RegExp(r'\bfdisk\b|\bparted\b', caseSensitive: false),
    RegExp(r'\bdocker\s+(container\s+)?rm\b', caseSensitive: false),
    RegExp(r'\bdocker\s+volume\s+(rm|prune)\b', caseSensitive: false),
    RegExp(r'\bdocker\s+system\s+prune\b', caseSensitive: false),
    RegExp(r'\bdocker\s+network\s+(rm|prune)\b', caseSensitive: false),
    RegExp(r'\bdocker\s+compose\s+(down|-f\s+\S+\s+down)\b', caseSensitive: false),
    RegExp(r'\b(DROP\s+DATABASE|DROP\s+TABLE|TRUNCATE\s+TABLE|TRUNCATE|DELETE\s+FROM)\b', caseSensitive: false),
    RegExp(r'\biptables\s+(-F|--flush)\b', caseSensitive: false),
    RegExp(r'\bufw\s+(reset|disable)\b', caseSensitive: false),
    RegExp(r'>\s*/dev/sd[a-z]', caseSensitive: false),
    RegExp(r':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:', caseSensitive: false), // Fork bomb
  ];

  static final List<RegExp> _serviceChangePatterns = [
    RegExp(r'\bdocker\s+(container\s+)?(restart|stop|start|pause|unpause)\b', caseSensitive: false),
    RegExp(r'\bdocker\s+compose\s+(restart|stop|start|up\s+-d)\b', caseSensitive: false),
    RegExp(r'\bsystemctl\s+(restart|stop|start|reload)\b', caseSensitive: false),
    RegExp(r'\bservice\s+\S+\s+(restart|stop|start|reload)\b', caseSensitive: false),
    RegExp(r'\bnginx\s+-s\s+(reload|stop|quit)\b', caseSensitive: false),
    RegExp(r'\bkill\b|\bpkill\b|\bkillall\b', caseSensitive: false),
  ];

  /// Evaluates command string and returns its safe risk classification.
  /// If [declaredRisk] is provided, it will NEVER downgrade an inherently risky command.
  static CommandRisk analyze(String commandText, [CommandRisk declaredRisk = CommandRisk.readOnly]) {
    final trimmed = commandText.trim();
    if (trimmed.isEmpty) return CommandRisk.readOnly;

    // Check destructive first
    for (final pattern in _destructivePatterns) {
      if (pattern.hasMatch(trimmed)) {
        return CommandRisk.destructive;
      }
    }

    // Check service change
    for (final pattern in _serviceChangePatterns) {
      if (pattern.hasMatch(trimmed)) {
        // If declared was already destructive, keep destructive
        return declaredRisk == CommandRisk.destructive ? CommandRisk.destructive : CommandRisk.serviceChange;
      }
    }

    // If declared risk was higher than readOnly, respect the higher risk
    return declaredRisk;
  }

  /// Whether a command is allowed to be run as a one-tap quick action.
  /// Destructive commands are strictly prohibited as quick actions.
  static bool isAllowedAsQuickAction(String commandText) {
    return analyze(commandText) != CommandRisk.destructive;
  }
}
